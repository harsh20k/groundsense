import json
import os
from datetime import datetime
import urllib.request
import urllib.error
import re
import boto3

s3 = boto3.client('s3')

S3_BUCKET_NAME = os.environ['S3_BUCKET_NAME']


def fetch_publication_list():
    """Fetch list of earthquake publications from NRCan."""
    url = "https://www.earthquakescanada.nrcan.gc.ca/pprs-pprp/index-en.php"
    
    try:
        print(f"Fetching publications from: {url}")
        req = urllib.request.Request(
            url,
            headers={'User-Agent': 'GroundSense/1.0'}
        )
        
        with urllib.request.urlopen(req, timeout=30) as response:
            html = response.read().decode('utf-8')
            
            # Parse for PDF document links
            pdf_pattern = re.compile(r'href="([^"]*\.pdf)"', re.IGNORECASE)
            pdf_links = pdf_pattern.findall(html)
            
            # Make URLs absolute
            absolute_links = []
            for link in pdf_links:
                if link.startswith('/'):
                    absolute_links.append(f"https://www.earthquakescanada.nrcan.gc.ca{link}")
                elif not link.startswith('http'):
                    absolute_links.append(f"https://www.earthquakescanada.nrcan.gc.ca/{link}")
                else:
                    absolute_links.append(link)
            
            print(f"Found {len(absolute_links)} PDF publications")
            return absolute_links
    except urllib.error.URLError as e:
        print(f"Error fetching publication list: {e}")
        return []
    except Exception as e:
        print(f"Unexpected error fetching publications: {e}")
        return []


def download_and_upload_document(pdf_url):
    """Download a PDF document and upload to S3.
    
    Returns:
        'uploaded' if successfully uploaded
        'skipped' if already exists
        'failed' if error occurred
    """
    try:
        # Extract filename from URL
        filename = pdf_url.split('/')[-1]
        if not filename.endswith('.pdf'):
            filename = f"{filename}.pdf"
        
        # Clean filename for S3
        filename = re.sub(r'[^\w\-\.]', '_', filename)
        
        # Check if document already exists in S3
        now = datetime.utcnow()
        s3_key = f"{now.year}/{filename}"
        
        try:
            s3.head_object(Bucket=S3_BUCKET_NAME, Key=s3_key)
            print(f"Document {filename} already exists in S3, skipping")
            return 'skipped'
        except s3.exceptions.ClientError:
            pass  # Document doesn't exist, proceed with upload
        
        # Download PDF
        print(f"Downloading {pdf_url}")
        req = urllib.request.Request(
            pdf_url,
            headers={'User-Agent': 'GroundSense/1.0'}
        )
        
        with urllib.request.urlopen(req, timeout=60) as response:
            pdf_content = response.read()
        
        # Verify it's a PDF
        if not pdf_content.startswith(b'%PDF'):
            print(f"Warning: {filename} does not appear to be a valid PDF")
            return 'failed'
        
        # Upload to S3
        s3.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=s3_key,
            Body=pdf_content,
            ContentType='application/pdf',
            Metadata={
                'source_url': pdf_url,
                'fetched_at': datetime.utcnow().isoformat()
            }
        )
        
        print(f"✓ Uploaded {filename} to S3 at {s3_key} ({len(pdf_content)} bytes)")
        return 'uploaded'
    
    except Exception as e:
        print(f"✗ Error downloading/uploading document {pdf_url}: {e}")
        return 'failed'


def lambda_handler(event, context):
    """Lambda handler for document fetching."""
    print("Starting document fetch from NRCan Earthquakes Canada...")
    
    # Fetch and process earthquake publications
    pdf_links = fetch_publication_list()
    
    if not pdf_links:
        print("No PDF links found to process")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'No documents found to fetch',
                'documents_processed': 0
            })
        }
    
    # Download and upload each PDF
    successful_uploads = 0
    failed_uploads = 0
    skipped_uploads = 0
    
    for pdf_url in pdf_links:
        try:
            result = download_and_upload_document(pdf_url)
            if result == 'uploaded':
                successful_uploads += 1
            elif result == 'skipped':
                skipped_uploads += 1
        except Exception as e:
            print(f"Failed to process {pdf_url}: {e}")
            failed_uploads += 1
    
    print(f"Document fetch completed: {successful_uploads} uploaded, {skipped_uploads} skipped, {failed_uploads} failed")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Document fetch completed',
            'documents_found': len(pdf_links),
            'documents_uploaded': successful_uploads,
            'documents_skipped': skipped_uploads,
            'documents_failed': failed_uploads
        })
    }

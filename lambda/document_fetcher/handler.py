import json
import os
from datetime import datetime
import urllib.request
import urllib.error
import re
import boto3

s3 = boto3.client('s3')

S3_BUCKET_NAME = os.environ['S3_BUCKET_NAME']


def fetch_notable_events_list():
    """Fetch list of notable earthquake events from NRCan."""
    url = "https://earthquakescanada.nrcan.gc.ca/notable-event/index-en.php"
    
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            html = response.read().decode('utf-8')
            
            # Parse for document links (simplified - in production use BeautifulSoup)
            # Looking for patterns like: href=".*\.pdf" or notable event links
            pdf_pattern = re.compile(r'href="([^"]*\.pdf)"', re.IGNORECASE)
            pdf_links = pdf_pattern.findall(html)
            
            print(f"Found {len(pdf_links)} potential PDF links")
            return pdf_links[:10]  # Limit to 10 for initial implementation
    except urllib.error.URLError as e:
        print(f"Error fetching notable events list: {e}")
        return []


def download_and_upload_document(pdf_url):
    """Download a PDF document and upload to S3."""
    try:
        # Make URL absolute if relative
        if pdf_url.startswith('/'):
            pdf_url = f"https://earthquakescanada.nrcan.gc.ca{pdf_url}"
        elif not pdf_url.startswith('http'):
            pdf_url = f"https://earthquakescanada.nrcan.gc.ca/{pdf_url}"
        
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
            return
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
        
        print(f"Uploaded {filename} to S3 at {s3_key}")
    
    except Exception as e:
        print(f"Error downloading/uploading document {pdf_url}: {e}")


def lambda_handler(event, context):
    """Lambda handler for document fetching."""
    print("Starting document fetch...")
    
    # For Phase 1, we'll create a stub that demonstrates the capability
    # In production, this would parse the NRCan notable events page
    
    # Example stub: create a sample metadata document
    now = datetime.utcnow()
    stub_metadata = {
        'title': 'GroundSense Document Fetcher - Stub',
        'description': 'This is a Phase 1 stub. Phase 2 will fetch actual GSC PDFs.',
        'timestamp': now.isoformat(),
        'note': 'Replace this with actual PDF fetching from NRCan notable events page'
    }
    
    s3_key = f"{now.year}/stub_metadata_{now.strftime('%Y%m%d_%H%M%S')}.json"
    
    s3.put_object(
        Bucket=S3_BUCKET_NAME,
        Key=s3_key,
        Body=json.dumps(stub_metadata, indent=2),
        ContentType='application/json'
    )
    
    print(f"Created stub document at {s3_key}")
    
    # Fetch and process actual documents (commented out for Phase 1 stub)
    # pdf_links = fetch_notable_events_list()
    # for pdf_url in pdf_links:
    #     download_and_upload_document(pdf_url)
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Document fetch completed (stub)',
            'note': 'Phase 1 stub - will fetch actual PDFs in Phase 2'
        })
    }

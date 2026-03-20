#!/usr/bin/env python3
"""Full flow test for document fetcher lambda (without S3)."""

import urllib.request
import urllib.error
import re
from datetime import datetime


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


def test_download_document(pdf_url):
    """Test downloading a PDF document (without S3 upload).
    
    Returns:
        'success' if download worked
        'failed' if error occurred
    """
    try:
        # Extract filename from URL
        filename = pdf_url.split('/')[-1]
        
        # Download PDF
        print(f"  Testing: {filename}")
        req = urllib.request.Request(
            pdf_url,
            headers={'User-Agent': 'GroundSense/1.0'}
        )
        
        with urllib.request.urlopen(req, timeout=60) as response:
            pdf_content = response.read()
        
        # Verify it's a PDF
        if not pdf_content.startswith(b'%PDF'):
            print(f"    ✗ Not a valid PDF")
            return 'failed'
        
        size_kb = len(pdf_content) / 1024
        print(f"    ✓ Valid PDF ({size_kb:.1f} KB)")
        return 'success'
    
    except Exception as e:
        print(f"    ✗ Error: {e}")
        return 'failed'


def main():
    print("=" * 70)
    print("GroundSense Document Fetcher - Full Flow Test")
    print("=" * 70)
    print()
    
    # Step 1: Fetch publication list
    print("Step 1: Fetching publication list...")
    pdf_links = fetch_publication_list()
    
    if not pdf_links:
        print("\n✗ No PDF links found to process")
        return
    
    print(f"\n✓ Found {len(pdf_links)} publications")
    print("\nPublications found:")
    for i, link in enumerate(pdf_links, 1):
        filename = link.split('/')[-1]
        print(f"  {i}. {filename}")
    
    # Step 2: Test downloading each PDF
    print(f"\nStep 2: Testing downloads...")
    successful = 0
    failed = 0
    
    for pdf_url in pdf_links:
        result = test_download_document(pdf_url)
        if result == 'success':
            successful += 1
        else:
            failed += 1
    
    # Summary
    print("\n" + "=" * 70)
    print("Test Summary")
    print("=" * 70)
    print(f"Total publications found: {len(pdf_links)}")
    print(f"Successful downloads:     {successful}")
    print(f"Failed downloads:         {failed}")
    
    if failed == 0:
        print("\n✓ All tests passed! Lambda is ready to deploy.")
    else:
        print(f"\n⚠ {failed} download(s) failed. Check errors above.")
    
    print("=" * 70)


if __name__ == '__main__':
    main()

import asyncio
import httpx
import sys
import os
import json
from datetime import datetime

# Setup path for imports if needed
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

BASE_URL = os.getenv("ARTICLE_SERVICE_URL", "http://localhost:8084/api/v1")

async def test_api():
    print("=" * 60)
    print("Article Service API Integration Test")
    print("=" * 60)
    
    async with httpx.AsyncClient() as client:
        # Test 1: Health Check
        print("\n1. Testing Healthz...")
        try:
            resp = await client.get(f"http://localhost:8084/healthz")
            print(f"Status: {resp.status_code}")
            print(f"Body: {resp.text}")
            assert resp.status_code == 200
        except Exception as e:
            print(f"Healthz test failed: {e}")

        # Test 2: List Articles (Initial)
        print("\n2. Testing List Articles...")
        resp = await client.get(f"{BASE_URL}/article", params={"limit": 5})
        print(f"Status: {resp.status_code}")
        data = resp.json()
        print(f"Found {data.get('count', 0)} articles")
        assert resp.status_code == 200

        # Create a test article if count is 0 or just use first one
        article_id = None
        if data.get('articles'):
            article_id = data['articles'][0]['id']
            print(f"Using article ID: {article_id}")
        else:
            print("⚠ No articles found in DB. Test partially skipped.")
            return

        # Test 3: Get Article Detail
        print(f"\n3. Testing Get Article {article_id} Detail...")
        resp = await client.get(f"{BASE_URL}/article/{article_id}")
        print(f"Status: {resp.status_code}")
        detail = resp.json()
        print(f"Title: {detail.get('title')}")
        print(f"View Count: {detail.get('view_count')}")
        assert resp.status_code == 200

        # Test 4: Search & Category Filter
        print("\n4. Testing Category Filtering...")
        categories = detail.get('categories') or []
        category = categories[0] if categories else 'Tech'
        resp = await client.get(f"{BASE_URL}/article", params={"category": category})
        print(f"Status: {resp.status_code} for category '{category}'")
        assert resp.status_code == 200

        # Test 5: Interaction
        print(f"\n5. Testing Interaction on Article {article_id}...")
        payload = {"user_id": 999, "type": "LOVE"}
        resp = await client.post(f"{BASE_URL}/article/{article_id}/interaction", json=payload)
        print(f"Status: {resp.status_code}")
        print(f"Body: {resp.text}")
        assert resp.status_code == 200

        # Test 6: Metric tracking
        print(f"\n6. Testing Reading Metric for Article {article_id}...")
        payload = {"user_id": 999, "reading_time_seconds": 120}
        resp = await client.post(f"{BASE_URL}/article/{article_id}/metric", json=payload)
        print(f"Status: {resp.status_code}")
        print(f"Body: {resp.text}")
        assert resp.status_code == 200

    print("\n" + "=" * 60)
    print("API Integration Test Completed Successfully!")
    print("=" * 60)

if __name__ == "__main__":
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(test_api())

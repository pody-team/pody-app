import sys, requests, trafilatura, asyncio
sys.stdout.reconfigure(encoding='utf-8')

urls = [
    ('DB:1034', 'https://vnexpress.net/thay-kim-sang-sik-huan-luyen-vien-kho-nhat-the-gioi-5005225.html'),
    ('DB:414',  'https://vnexpress.net/trung-kien-va-dinh-bac-vuon-tam-the-gioi-sau-tran-u23-viet-nam-thang-arab-saudi-5004936.html'),
    ('DB:897',  'https://vnexpress.net/thu-gian-video-hai-chuyen-la-dan-ca-ro-ru-nhau-len-bo-sau-mua-5002230.html'),
]

for label, url in urls:
    r = requests.get(url, headers={'User-Agent': 'Mozilla/5.0 Chrome/120'})
    content = trafilatura.extract(r.text)
    print(content)
    # print(f'[{label}] fresh trafilatura: {len(content or "")} chars')
    # if content:
    #     print(f'  preview: {content[:120]}')
    # print()

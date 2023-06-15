import requests
import json

def fetch_lottery_history(page_size):
    url = 'https://webapi.sporttery.cn/gateway/lottery/getHistoryPageListV1.qry'
    headers = {
        'authority': 'webapi.sporttery.cn',
        'accept': 'application/json, text/javascript, */*; q=0.01',
        'accept-language': 'zh-CN,zh;q=0.9',
        'origin': 'https://static.sporttery.cn',
        'referer': 'https://static.sporttery.cn/',
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-site',
        'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36'
    }
    params = {
        'gameNo': '85',
        'provinceId': '0',
        'pageSize': str(page_size),
        'isVerify': '1',
        'pageNo': '1'
    }
    response = requests.get(url, headers=headers, params=params)
    data = response.json()

    if data.get('success'):
        history_list = data.get('value').get('list')
        result = []
        for history in history_list:
            lotteryDrawNum = history.get('lotteryDrawNum')
            lotteryDrawResult = history.get('lotteryDrawResult')
            lotteryDrawTime = history.get('lotteryDrawTime')

            result.append({
                'lotteryDrawNum': lotteryDrawNum,
                'lotteryDrawResult': lotteryDrawResult,
                'lotteryDrawTime': lotteryDrawTime
            })
        print(json.dumps(result, indent=4))
    else:
        print('Failed to fetch lottery history.')

# 设置要采集的历史开奖期数
page_size = 10

fetch_lottery_history(page_size)



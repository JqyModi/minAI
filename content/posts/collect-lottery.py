import requests
import json

def fetch_lottery_history(page_size, printType):
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

            if printType == 0 :
                result.append({
                    'lotteryDrawNum': lotteryDrawNum,
                    'lotteryDrawResult': lotteryDrawResult,
                    'lotteryDrawTime': lotteryDrawTime
                })
            else:
                result.append(lotteryDrawResult)


        print(json.dumps(result, indent=4))
    else:
        print('Failed to fetch lottery history.')

# 设置要采集的历史开奖期数
page_size = 50
# 获取打印的JSON格式：0代表{key1:value1, ...} 1代表[value1, value2, ...]
printType = 1

fetch_lottery_history(page_size, printType)



# 你将扮演一名经验丰富的数据科学家，专注于数据分析和机器学习。你具备数十年在数据科学领域的实践经验，致力于解决复杂问题并提供深入的数据洞察。
# 作为数据科学家，你具备以下关键能力：
# 1. 数据分析和处理：你熟练运用各种数据分析工具和编程语言，如Python和R，能够收集、清洗、探索和可视化数据，并运用统计分析方法从中提取有意义的信息。
# 2. 机器学习和模型建立：你拥有扎实的机器学习背景，熟悉各种机器学习算法和技术，包括监督学习、无监督学习和深度学习。你能够构建和优化机器学习模型，以预测和分类数据，发现模式和趋势。
# 在你多年的职业生涯中，你积累了丰富的经验，你擅长应用数据科学技术解决以下问题：
# 1. 预测分析：通过分析历史数据和趋势，你能够开发准确的预测模型，帮助组织做出未来的决策和规划。

# 我会以`/q [
#     "02 28 30 33 35 02 10",
#     "06 11 13 30 32 01 03",
#     "08 14 16 21 25 03 12",
# ...
# ]`的格式向你提问，[]中代表大乐透的多期历史开奖号码，数组第一个元素代表最近一期开奖号码，你要用你专业的数据分析能力及丰富的从业经验帮我分析预测下一期最有可能的两组开奖号码，
# 以JSON数组格式发送给我

# [如果你已经理解了请回复`我已理解`，记住当我以`/q [...]`格式向你提问的时候，你应该优先给我预测的开奖号码而不是正在处理之类的回复]
# [回答全部使用中文]

#import requests

import sys
import json
from bs4 import BeautifulSoup
from datetime import datetime, timedelta
# 获取通过ajxs动态加载数据的HTML内容
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options


# 这种方式只能用来抓取静态HTML页面 
# response = requests.get(url)

# 记录需要获取的历史开奖期数：最大是30
num_of_periods = 30

# 收集结果集中应包含的期数

if len(sys.argv) == 1:
    print("No arguments provided.")
else:
    print("Arguments provided:", sys.argv[1:])
    num_of_periods = int(sys.argv[1])

# 发送请求，获取网页内容
# 通过网页分析发现https://www.lottery.gov.cn/kj/kjlb.html?dlt中的开奖信息其实是通过iframe内嵌了一个HTML展示的
# 所以这里直接获取内嵌的HTML对应的URL链接[通过网页 - 检查 - 选中iframe右键可复制]
url = 'https://static.sporttery.cn/res_1_0/jcw/default/html/kj/dlt.html?url=//www.lottery.gov.cn&cmData={"advUrl":"/htmlfrag","webApi":"//webapi.sporttery.cn","resDomain":"//static.sporttery.cn","res":"//static.sporttery.cn/res_1_0/tcw/default","env":"prd","domain1":"www.lottery.gov.cn","domain2":"www.sporttery.cn","domain3":"m.lottery.gov.cn","domain4":"m.sporttery.cn","domain5":"www.lottery.gov.cn","domain6":"www.sporttery.cn","domain7":"m.lottery.gov.cn","domain8":"m.sporttery.cn"}'

# 创建 Chrome WebDriver 对象
# driver = webdriver.Chrome()

# 创建 Chrome WebDriver 对象并设置无头模式[可以不用动态打开谷歌浏览器加载URL]
options = Options()
options.add_argument('--headless')
driver = webdriver.Chrome(options=options)

# 创建 WebDriverWait 对象
wait = WebDriverWait(driver, 10)

# 打开网页
driver.get(url)

# 等待数据加载完成，等待条件为指定元素可见 -> CSS_SELECTOR 可以通过浏览器右键复制selector
wait.until(EC.visibility_of_element_located((By.CSS_SELECTOR, '#historyData > tr:nth-child(1) > td.u-dltnext.lineb2Rt')))

# 获取加载后的HTML内容
html = driver.page_source

# 关闭浏览器窗口
driver.quit()

soup = BeautifulSoup(html, 'html.parser')

table = soup.select('tbody#historyData')

rows = soup.select('tbody#historyData tr')

data = []
for row in rows:
    lotteryDate = row.select_one('td:first-child').text
    lotteryDrawNum = row.select_one('td.lineb2Rt').text.strip()
    lotteryDrawResult = [int(td.text.strip()) for td in row.select('td.u-dltpre, td.u-dltnext')]

    if len(lotteryDate) != 5 :
        continue

    data.append({
        'lotteryDate': lotteryDate,
        'lotteryDrawNum': lotteryDrawNum,
        'lotteryDrawResult': lotteryDrawResult
    })

    if len(data) == num_of_periods :
        break

json_data = json.dumps(data, ensure_ascii=False, indent=4)
print(json_data)


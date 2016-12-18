# !/usr/bin/env python3
# -*- coding:utf-8 -*-

# import relative python libs

import urllib
import http.cookiejar
import re
import hashlib
import time
import datetime

from bs4 import BeautifulSoup

import sys
import io
import smtplib

from email.mime.text import MIMEText
from email.header import Header

sys.stdout = io.TextIOWrapper(sys.stdout.buffer,encoding='utf8')

# The tian jin University library login Web Entry point

url_login = 'http://opac.lib.tju.edu.cn/opac/reader/doLogin'


# The User Name and Password of Sunya

user = '2015203218'
passwd = '321123'.encode('utf-8')


# use MD5 encrypt the user password

md5=hashlib.md5()
md5.update(passwd)
md5Passwd=md5.hexdigest()


# login with user name and encrypted password 

data = {'rdid': user, 'rdPasswd':md5Passwd}
data = urllib.parse.urlencode(data).encode(encoding='utf-8')
req=urllib.request.Request(url_login)
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor())
response =  opener.open(req,data)


# enter the  book renew page

loanRenew='http://opac.lib.tju.edu.cn/opac/loan/renewList'
renewReq = urllib.request.Request(loanRenew)
response = opener.open(renewReq);


# find the loaned books list

soup = BeautifulSoup(response)
tables = soup.findAll('table')
tab = tables[0]


# print the loaned books 

print('\nYou have loaned books list as follow:')
print 

bookList = []
for tr in tab.findAll('tr'):
	ths= tr.findAll('th')
	ths = ths[1:-1]
	for th in ths:
		print(th.getText(),end=' ')
	if(len(ths)!=0):
		print()

	book=[]
	tds = tr.findAll('td')
	tds = tds[1:-1]
	for td in tds:
		field = td.getText()
		book.append(field)
		print(td.getText(),end=' ');
	if(len(book)!=0):
		bookList.append(book)	
		print()

outDateBooks=[]
cannotRenewBooks=[]
canRenewBooks=[]
shouldReturnBooks=[]
validDateBooks=[]

returnPreDays=1
maxRenewCount = 2

for book in bookList:
	barcode = book[0]
	name = book[1]
	index = book[2]
	location = book[3]
	type = book[4]
	volume = book[5]
	loanDate = book[6]
	returnDate = book[7]
	renewCount = book[8]

	curDate = time.localtime(time.time())
	retDate = time.strptime(returnDate,'%Y-%m-%d')
	curDateTime = datetime.datetime(curDate[0],curDate[1],curDate[2],curDate[3],curDate[4],curDate[5])
	retDateTime = datetime.datetime(retDate[0],retDate[1],retDate[2],retDate[3],retDate[4],retDate[5])
	deltaDays = (retDateTime-curDateTime).days
	if(deltaDays < 0):
		outDateBooks.append(book)
		shouldReturnBooks.append(book)
	elif((deltaDays <= returnPreDays) and (int(renewCount) < maxRenewCount)):
		canRenewBooks.append(book)
	elif(int(renewCount) >= maxRenewCount):
		cannotRenewBooks.append(book)	
		shouldReturnBooks.append(book)
	else:
		validDateBooks.append(book)
			
		
def showBooksInfo(books):
	if(not isinstance(books,list)):
		return
	for book in books:
		for field in book:
			print(field,end=' ')
		print()


if(len(outDateBooks)>0):
	print('\nout date books:')
	showBooksInfo(outDateBooks)

if(len(shouldReturnBooks) > 0):
	print('\nshould return books:')
	showBooksInfo(shouldReturnBooks)

if(len(canRenewBooks) > 0):
	print('\ncan renew books:')
	showBooksInfo(canRenewBooks)

if(len(cannotRenewBooks) > 0):
	print('\ncan not renew books:')
	showBooksInfo(cannotRenewBooks)

if(len(validDateBooks) > 0):
	print('\nvalid Date books:')
	showBooksInfo(validDateBooks)

loanDoRenew='http://opac.lib.tju.edu.cn/opac/loan/doRenew'
furl='http://opac.lib.tju.edu.cn/opac/loan/renewList'

if(len(canRenewBooks) > 0):
	print('\nrenewed books:\n')
	showBooksInfo(canRenewBooks)

for book in canRenewBooks:
	barcode = book[0] 
	renewList =  {'barcodeList': barcode, 'furl':furl}
	data = urllib.parse.urlencode(renewList).encode(encoding='utf-8')
	req=urllib.request.Request(loanDoRenew)
	response =  opener.open(req,data)

# send the hint email to recivers 

if len(shouldReturnBooks) <= 0 :
	exit(0)

sender = 'joker<824219521@qq.com>'
receivers = '2292387471@qq.com'
subject = '天津大学图书馆图书归还提示'
smtpserver = 'smtp.qq.com'
username = '824219521'
password = '!@#zhulongyixian'

content='<html><title>Joker</title><body><h3>孙亚，你有<b>%d</b>本书应该归还了;-D，它们是:</h3>' % len(shouldReturnBooks)
index = 1
for book in shouldReturnBooks:
	content += '(%d)<b>%s</b>(%s)<br>借出日期: %s<br>截止日期: %s<br>已续借%s次<br><br>' % (index,book[1],book[0],book[6],book[7],book[8])
	index = index + 1
content+='<a href="http://opac.lib.tju.edu.cn/opac/reader/doLogin">天津大学图书馆登录确认</a><p align="right">——本消息来自Joker的树莓机器人</p></body></html>'

msg = MIMEText(content,'html','utf-8')
msg['Subject']=Header(subject,'utf-8')
msg['From'] = Header(sender,'utf-8')
msg['To'] = Header(receivers,'utf-8')
msg['Cc']=Header(sender,'utf-8')

try:
	smtp = smtplib.SMTP()
	smtp.connect(smtpserver)
	smtp.login(username,password)
	smtp.sendmail(sender,receivers,msg.as_string())
except smtplib.SMTPException:
	print("Error: 无法发送邮件")
	
smtp.quit()

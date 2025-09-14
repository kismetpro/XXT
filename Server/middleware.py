from flask import request
from flask import jsonify, Response
from utils.aes import *
from utils.constants import *
import time
import utils.log
import pymysql
from student import Student

VERSION = '1.1.0' # 服务端版本号，最后一位留0，任意patch版本均可过校验

log = utils.log.Log('Flask')

IGNORE_TOKEN_URL = set({'/login'})
IGNORE_BEFORE_REQUEST = set({'/imageProxy'})

def parseVersion(version: str):
  if not version:
    return 0, 0, 0
  parts = version.split('.')
  if len(parts) != 3:
    return 0, 0, 0
  try:
    major = int(parts[0])
    minor = int(parts[1])
    patch = int(parts[2])
    return major, minor, patch
  except ValueError:
    return 0, 0, 0

def after_request(resp: Response):
  if (resp.json is not None):    
    if (resp.json['suc']):
      log.s(f"{resp.json}")
    else:
      log.w(f"{resp.json}")
  return resp
 
def before_request():
  if any([request.path.startswith(url) for url in IGNORE_BEFORE_REQUEST]):
    return
  conn = POOL.connection()
  cursor = conn.cursor(pymysql.cursors.DictCursor)
  version = request.headers.get('version')
  if not version or parseVersion(version) == (0, 0, 0):
    return {'suc': False, 'msg': 'version is required'}, 403
  if parseVersion(version)[0] < parseVersion(VERSION)[0] or parseVersion(version)[1] < parseVersion(VERSION)[1]:
    return {'suc': False, 'msg': f'版本过低, 请更新v{VERSION}'}
  if not any([request.path.startswith(url) for url in IGNORE_TOKEN_URL]):
    token = request.headers.get('token')
    if not token or token == '':
      return {'suc': False, 'msg': 'Token is required'}, 403
    data = decodeToken(token)
    cursor.execute("select uid, name, token from UserInfo where mobile=%s", (data['mobile']))
    if cursor.rowcount == 0:
      return {'suc': False, 'msg': 'user error'}, 403
    dbToken = cursor.fetchone()['token']
    dbData = decodeToken(dbToken)
    if dbData['password'] != data['password']:
      return {'suc': False, 'msg': 'password error'}, 403
    student = Student(data['mobile'], data['password'])
    request.json['student'] = student
  request.json['cursor'] = cursor
  request.json['conn'] = conn

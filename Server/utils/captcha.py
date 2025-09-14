import ddddocr
import execjs
import requests
import json
import re

def check_captcha(session):
  with open('./js/generateCaptchaKey.js', encoding='utf-8') as f:
    js = f.read()

  # 通过compile命令转成一个js对象
  docjs = execjs.compile(js)

  # 调用function
  res = docjs.call('generateCaptchaKey')
  ckey = res['captchaKey']
  token = res['token']

  headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Referer': 'https://office.chaoxing.com/front/third/apps/seatengine/select',
    'Accept': 'application/json, text/javascript, */*; q=0.01'
  }

  res = session.get(f'https://captcha.chaoxing.com/captcha/get/verification/image?callback=cx_captcha_function&captchaId=42sxgHoTPTKbt0uZxPJ7ssOvtXr3ZgZ1&type=slide&version=1.1.20&captchaKey={ckey}&token={token}&referer=https%3A%2F%2Fmobilelearn.chaoxing.com%2Fpage%2Fsign%2FsignIn%3FcourseId%3D250447992%26classId%3D116562693%26activeId%3D1000125245417%26fid%3D0%26timetable%3D0', headers=headers)
  captcha_data = json.loads(re.search(r'\{.*\}', res.text)[0])
  background = requests.get(captcha_data["imageVerificationVo"]["shadeImage"],headers=headers).content
  target = requests.get(captcha_data["imageVerificationVo"]["cutoutImage"],headers=headers).content
  token_new = captcha_data["token"]
  det = ddddocr.DdddOcr(det=False, ocr=False, show_ad=False)
  res_det = det.slide_match(target, background,simple_target=True)

  data_check = {
      "callback": "callback",
      "captchaId": "42sxgHoTPTKbt0uZxPJ7ssOvtXr3ZgZ1",
      "type": "slide",
      "token": token_new,
      "textClickArr": ('[{{\"x\":{x}}}]').format(x=res_det['target'][0]),
      "coordinate": "[]",
      "runEnv": "10",
      "version": "1.1.14"
  }
  jgyz = ('[{{\"x\":{x}}}]').format(x=res_det['target'][0])
  head = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36 Edg/136.0.0.0",
    "Connection": "keep-alive",
    "Accept": "*/*",
    "Accept-Encoding": "gzip, deflate, br, zstd",
    "sec-ch-ua-platform": "\"Windows\"",
    "sec-ch-ua": "\"Chromium\";v=\"136\", \"Microsoft Edge\";v=\"136\", \"Not.A/Brand\";v=\"99\"",
    "sec-ch-ua-mobile": "?0",
    "Sec-Fetch-Site": "same-site",
    "Sec-Fetch-Mode": "no-cors",
    "Sec-Fetch-Dest": "script",
    "Referer": "https://mobilelearn.chaoxing.com/page/sign/signIn?courseId=250447992&classId=116562693&activeId=1000125245417&fid=0&timetable=0",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6"
  }
  res_check = session.get(
    f"https://captcha.chaoxing.com/captcha/check/verification/result?callback=cx_captcha_function&captchaId=42sxgHoTPTKbt0uZxPJ7ssOvtXr3ZgZ1&type=slide&token={token_new}&textClickArr={jgyz}&coordinate=[]&runEnv=10&version=1.1.20", headers=head,
  )

  check_result = json.loads(re.search(r'\{.*\}', res_check.text)[0])
  if check_result['result']:
    return json.loads(check_result['extraData'])['validate']
  else:
    print('error')
    return res_check.text

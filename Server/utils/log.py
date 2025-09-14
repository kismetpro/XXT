class Log:
  def __init__(self, tag='default'):
    self.tag = tag

  def i(self, msg):
    print(f'\033[34mI: \t{self.tag} {msg}\033[0m')

  def e(self, msg):
    print(f'\033[31mE: \t{self.tag} {msg}\033[0m')  

  def w(self, msg):
    print(f'\033[33mW: \t{self.tag} {msg}\033[0m')

  def d(self, msg):
    print(f'D: \t{self.tag} {msg}')

  def s(self, msg):
    print(f'\033[32mS: \t{self.tag} {msg}\033[0m')

import os
from Crypto import Random
from Crypto.PublicKey import RSA

def save_key_to_file(filepath, key_data):
    """
    将密钥数据保存到文件。
    如果目录不存在，则会自动创建。
    """
    # 1. 获取文件所在的目录路径
    dir_path = os.path.dirname(filepath)
    
    # 2. 如果目录路径不为空，则创建目录（支持多级目录）
    #    os.makedirs 支持递归创建目录， exist_ok=True 确保目录已存在时不会报错
    if dir_path:
        os.makedirs(dir_path, exist_ok=True)
    
    # 3. 写入文件
    with open(filepath, "wb") as f:
        f.write(key_data)
    print(f"密钥已成功保存到: {filepath}")




# 1. 生成RSA密钥对
# 伪随机数生成器
random_generator = Random.new().read
# rsa算法生成实例
rsa = RSA.generate(1024, random_generator)

# 2. 导出私钥和公钥
private_pem = rsa.exportKey()
public_pem = rsa.publickey().exportKey()

# 3. 定义要保存的文件路径
private_key_path = "./Server/keys/private.pem"
public_key_paths = [
    "./Client/assets/keys/public.pem",
    "./Server/keys/public.pem",
    "./Web/public/keys/public.pem"
]

# 4. 保存私钥
save_key_to_file(private_key_path, private_pem)

# 5. 循环保存公钥到所有指定位置
for path in public_key_paths:
    save_key_to_file(path, public_pem)

print("\n所有密钥文件生成完毕！")
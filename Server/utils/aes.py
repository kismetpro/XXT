from Crypto.Cipher import AES
from Crypto.Util.Padding import pad
import base64
import json
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import hashes

def EncryptXXTByAes(message, key):
    # Convert string inputs to bytes
    message_bytes = message.encode('utf-8')
    key_bytes = key.encode('utf-8')
    
    # Ensure key is 16, 24, or 32 bytes long (AES-128, AES-192, or AES-256)
    # We'll pad or truncate the key to 16 bytes (AES-128) to match common CryptoJS behavior
    key_bytes = (key_bytes + b'\0' * 16)[:16]
    
    # Use key as IV (matching the CryptoJS example)
    iv = key_bytes
    
    # Create AES cipher object in CBC mode
    cipher = AES.new(key_bytes, AES.MODE_CBC, iv)
    
    # Pad the message to be multiple of block size (16 bytes) using PKCS7
    padded_data = pad(message_bytes, AES.block_size)
    
    # Encrypt the data
    ciphertext = cipher.encrypt(padded_data)
    
    # Return base64 encoded string
    return base64.b64encode(ciphertext).decode('utf-8')

def decodeToken(encrypted_base64: str) -> dict:

    with open('./keys/private.pem', "rb") as key_file:
        private_key = serialization.load_pem_private_key(
            key_file.read(),
            password=None,
        )
    
    # 将 base64 字符串解码为字节
    encrypted_bytes = base64.b64decode(encrypted_base64)
    
    # 使用私钥解密
    decrypted_bytes = private_key.decrypt(
        encrypted_bytes,
        padding.PKCS1v15(),
    )
    
    # 将解密后的字节转换为字符串
    txt =  decrypted_bytes.decode('utf-8')
    # 将解密的字节转换为字符串
    return json.loads(txt)
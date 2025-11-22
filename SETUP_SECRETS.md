# GitHub Secrets 配置指南

## 1. 生成 Android 签名密钥

```bash
# 生成手机 APP 密钥
keytool -genkey -v -keystore keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias

# 生成 TV APP 密钥
keytool -genkey -v -keystore keystore_tv.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-tv-key-alias
```

## 2. 转换密钥为 base64

```bash
# 手机 APP
base64 keystore.jks > keystore_base64.txt

# TV APP  
base64 keystore_tv.jks > keystore_tv_base64.txt
```

## 3. 在 GitHub 仓库中设置 Secrets

访问：https://github.com/zeke-chin/dart_simple_live/settings/secrets/actions

点击 "New repository secret" 添加以下 Secrets：

### 手机 APP:
- Name: `KEYSTORE_BASE64`
  Value: keystore_base64.txt 的内容（完整的 base64 字符串）

- Name: `STORE_PASSWORD`
  Value: 你设置的密钥库密码

- Name: `KEY_PASSWORD`
  Value: 你设置的密钥密码

- Name: `KEY_ALIAS`
  Value: my-key-alias（或你设置的别名）

### TV APP:
- Name: `TV_KEYSTORE_BASE64`
  Value: keystore_tv_base64.txt 的内容

- Name: `TV_STORE_PASSWORD`
  Value: TV 密钥库密码

- Name: `TV_KEY_PASSWORD`
  Value: TV 密钥密码

- Name: `TV_KEY_ALIAS`
  Value: my-tv-key-alias（或你设置的别名）

## 4. 保管好密钥文件

⚠️ **重要**: 
- 将 keystore.jks 和 keystore_tv.jks 妥善保管
- 不要提交到 Git 仓库
- 记住所有密码
- 如果丢失，将无法更新已发布的 APP

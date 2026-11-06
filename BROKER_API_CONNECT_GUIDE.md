# Panchayagnam · Broker API Linking & Live Trading Setup Guide

This guide provides direct links and instructions to connect your official broker APIs to Panchayagnam for live algorithmic execution and Parent-Children copy trading.

---

## 1. Supported Indian Brokers & Developer Portals

| Broker | Developer Portal Link | Credentials Required | SEBI IP Whitelist Required |
| :--- | :--- | :--- | :--- |
| **Angel One SmartAPI** | [smartapi.angelbroking.com](https://smartapi.angelbroking.com/) | API Key, Client ID, MPIN, TOTP Secret | Yes |
| **DhanHQ Open API** | [dhanhq.co](https://dhanhq.co/) | Client ID, Access Token | No |
| **Zerodha Kite Connect** | [kite.trade](https://kite.trade/) | API Key, API Secret, Request Token | Optional |
| **Upstox API v2** | [upstox.com/developer/api-documentation](https://upstox.com/developer/api-documentation/) | API Key, API Secret, Redirect URL | No |
| **Motilal Oswal API** | Motilal Partner/API Desk | Vendor Key, User ID, Password, API Key | Yes |
| **Fyers API v3** | [myapi.fyers.in](https://myapi.fyers.in/) | App ID, Secret Key, Access Token | No |

---

## 2. Step-by-Step Instructions by Broker

### Angel One (SmartAPI)
1. Go to [smartapi.angelbroking.com](https://smartapi.angelbroking.com/) and register/sign in with your Angel One Demat account.
2. Click **Create An App** $\rightarrow$ select **Trading API**.
3. Set App Name to `Panchayagnam Trade`.
4. Copy the generated **API Key**.
5. Enable **TOTP** in your Angel One profile (using Google Authenticator) and save the TOTP secret key.
6. In Panchayagnam, go to **Parent Children Trading** $\rightarrow$ **Trading Accounts** $\rightarrow$ click **+ Add Account**, choose **Angel One**, and enter your Client ID and API Key.

### Dhan (DhanHQ Open API)
1. Log in to [web.dhan.co](https://web.dhan.co/).
2. Go to **My Profile** $\rightarrow$ **DhanHQ Trading APIs**.
3. Generate an **Access Token** (valid for 30 days).
4. Copy your **Client ID** (6-10 digit number) and **Token**.
5. In Panchayagnam, click **+ Add Account**, select **Dhan**, and link your account.

---

## 3. SEBI IP Whitelisting Compliance
Under SEBI guidelines, automated order routing systems connecting to brokers like Angel One and Motilal require the server's outgoing IP address to be whitelisted.
- When running in **Paper Trading Mode**, IP whitelisting is not required.
- When running on a cloud server (e.g., Render, AWS, or DigitalOcean), assign a **Static IP / Elastic IP** and enter it into your broker developer dashboard.

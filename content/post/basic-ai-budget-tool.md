+++
date = '2025-06-10T08:54:35+08:00'
draft = true
title = '0基础开发AI语音记账工具（基于微信 + 云函数 + 飞书）'
tags = ["AI记账", "微信公众号", "腾讯云函数", "飞书", "Moonshot"]
categories = ["AI开发"]
+++


## 1. 系统目标

- 用户通过微信公众号发送语音或文本进行记账。
- 使用大语言模型解析语义，提取类型、金额、分类、日期等字段。
- 结构化数据保存至飞书多维表格，便于查询和管理。

## 2. 技术选型

- **前端入口**：微信公众号（支持语音和文本消息）
- **后端处理**：腾讯云函数（Node.js 环境）
- **AI 模型**：Moonshot API / ChatGPT API（也可集成 ChatGLM、通义千问等国产大模型）
- **数据库**：飞书多维表格（Bitable）

## 3. 开发环境配置

### 安装 Node.js 开发环境（Windows）

```bash
scoop install nodejs-lts vscode git
```

### 初始化项目并安装依赖

```bash
npm init -y
npm install axios chrono-node dayjs dotenv xml2js
```

### 配置环境变量 `.env`

```env
TOKEN=${自定义的微信公众号token}
MOONSHOT_API_KEY=${moonshot申请API KEY}
FEISHU_APP_ID=${飞书开放平台申请App ID}
FEISHU_APP_SECRET=${飞书开放平台申请App Secret}
FEISHU_APP_TOKEN=${用于记账的飞书多维表格标识}
TABLE_ID=${飞书表格ID}
```

## 4. 微信公众号对接流程

1. 微信公众平台中配置服务器 URL，需为 HTTPS，推荐使用自定义域名，如 `https://wx.example.com/wx`
2. 在腾讯云函数控制台创建新函数，上传打包好的 zip 文件（要包含 `node_modules`，不要打包env的敏感信息!!!）
3. 微信对接云函数会发一个GET请求校验，核心校验代码示例：

```js
const crypto = require("crypto");

exports.verifySignature = (event) => {
  const { signature, timestamp, nonce, echostr } = event.queryString || {};
  const arr = [TOKEN, timestamp, nonce].sort();
  const str = arr.join('');
  const sha1 = crypto.createHash('sha1').update(str).digest('hex');
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'text/plain'
    },
    body: sha1 === signature ? echostr : 'Invalid signature'
  };
};
```
4. 解析文字或语音消息此处不表，可以问GPT生成。

## 5. 云函数部署建议

> 腾讯云函数可白嫖三个月的新手免费额度，按量计费也很便宜

- 本地调试通过后打ZIP包上传函数，在云端自动安装
- 使用在线编辑器可快速调试逻辑
- 日志查看入口：云函数控制台 > 调试日志。需配置开通，也有免费额度。
- 微信公众号的外部回调，需要开启 POST 跨域支持，确保公网可访问

## 6. AI 模型处理逻辑：解析日期

如果不限制日期，大模型会胡乱推测。通过 prompt 提示当前日期，引导模型正确回复日期信息：

```js
client = new OpenAI({
    apiKey: `${MOONSHOT_API_KEY}`,
    baseURL: "https://api.moonshot.cn/v1",
})

exports.extract = async (text) =>  {
  const today = dayjs().format('YYYY年MM月DD')
  const res =  await client.chat.completions.create({
    model: 'moonshot-v1-8k',
    messages: [
      {
        role: 'system',
        content: `你是一个记账助手，请将用户输入的自然语言转换为如下格式：
        {"type":"支出/收入","amount":金额,"category":"分类","note":"备注","date":"YYYY-MM-DD"}。
        不要猜测日期，如果没有日期就按当前时间输出，当前是 ${today}`
      },
      {
        role: 'user',
        content: text
      }
    ],
    temperature: 0.3
  });

  const content = res.choices[0].message.content.trim();

  return JSON.parse(content);
}
```

## 7. 飞书表格对接

- 多维表格地址示例：`https://feishu.cn/base/${FEISHU_APP_TOKEN}?table=${TABLE_ID}`
- 需手动获取以下配置项：
  - `FEISHU_APP_TOKEN`
  - `TABLE_ID`

### 添加一条记账信息

```http
POST https://open.feishu.cn/open-apis/bitable/v1/apps/${FEISHU_APP_TOKEN}/tables/${TABLE_ID}/records
```

### 添加记录数据格式

```js
const records = {
    fields: {
      "类型": data.type,
      "金额": data.amount,
      "分类": data.category,
      "备注": data.note,
      "日期": data.date,
      "MsgId": data.MsgId
    }
};
await axios.post(url, records,
    {
    headers: {
    'Authorization': `Bearer ${token}`, //此token为接入飞书开放平台的认证token，需发http请求获取
    'Content-Type': 'application/json'
    }
});
```

### 常见错误提示

- 飞书接口 4xx，可能是认证token不对，或者请求的数据格式不对

## 8. 实用建议与扩展思路

- 全程可在ChatGPT指导下完成
- 直接使用微信语音，可以接入腾讯语音识别SDK
- 若用户在海外部署系统，可切换数据库方案至 Airtable，以提高稳定性

---
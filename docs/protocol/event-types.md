# 事件类型注册表

**协议版本**: v1.0  
**源文件**: `src/tyche/events.py`

---

## 命名规范（v3）

- **裸事件名**：使用下划线分隔的小写名称，如 `quote`, `trade`, `order_submit`
- **无点分隔符**：事件名中不使用 `.`（点号）
- **无参数化**：`instrument_id` 等参数放在 payload 中，不作为事件名的一部分
- **无前缀**：不使用 `streaming_` 等前缀

## 事件类型清单

### 行情数据事件（Market Data）

| 常量名 | 事件名 | 广播方向 | 数据格式 |
|--------|--------|---------|---------|
| `QUOTE` | `quote` | Gateway → Engine → 订阅者 | 行情快照 |
| `TRADE` | `trade` | Gateway → Engine → 订阅者 | 逐笔成交 |
| `BAR` | `bar` | 策略模块 → Engine → 订阅者 | K 线数据 |
| `ORDER_BOOK` | `orderbook` | Gateway → Engine → 订阅者 | 委托簿快照 |

#### quote payload 示例

```json
{
  "instrument_id": "au2512",
  "exchange": "SHFE",
  "bid_price": 488.50,
  "ask_price": 488.60,
  "last_price": 488.55,
  "volume": 12345,
  "timestamp": 1720000000.123
}
```

#### trade payload 示例

```json
{
  "instrument_id": "au2512",
  "exchange": "SHFE",
  "price": 488.55,
  "volume": 10,
  "direction": "buy",
  "timestamp": 1720000000.123
}
```

#### bar payload 示例

```json
{
  "instrument_id": "au2512",
  "interval": "1m",
  "open": 488.00,
  "high": 489.00,
  "low": 487.50,
  "close": 488.55,
  "volume": 500,
  "timestamp": 1720000000.0
}
```

---

### 订单流事件（Order Flow）

| 常量名 | 事件名 | 广播方向 | 数据格式 |
|--------|--------|---------|---------|
| `ORDER_SUBMIT` | `order_submit` | 策略模块 → Gateway | 下单请求 |
| `ORDER_APPROVED` | `order_approved` | Gateway → Engine → 订阅者 | 订单已接受 |
| `ORDER_REJECTED` | `order_rejected` | Gateway → Engine → 订阅者 | 订单被拒绝 |
| `ORDER_EXECUTE` | `order_execute` | Gateway → Engine → 订阅者 | 订单执行 |
| `ORDER_CANCEL` | `order_cancel` | 策略模块 → Gateway | 撤单请求 |
| `ORDER_UPDATE` | `order_update` | Gateway → Engine → 订阅者 | 订单状态更新 |

#### order_submit payload 示例

```json
{
  "instrument_id": "au2512",
  "exchange": "SHFE",
  "direction": "buy",
  "offset": "open",
  "price": 488.50,
  "volume": 5,
  "order_type": "limit"
}
```

---

### 成交事件（Fill）

| 常量名 | 事件名 | 广播方向 | 数据格式 |
|--------|--------|---------|---------|
| `FILL` | `fill` | Gateway → Engine → 订阅者 | 成交通知 |

#### fill payload 示例

```json
{
  "instrument_id": "au2512",
  "exchange": "SHFE",
  "order_id": "ORD-20260101-001",
  "trade_id": "TRD-001",
  "price": 488.55,
  "volume": 5,
  "direction": "buy",
  "commission": 10.0,
  "timestamp": 1720000000.456
}
```

---

### 组合事件（Portfolio）

| 常量名 | 事件名 | 广播方向 | 数据格式 |
|--------|--------|---------|---------|
| `POSITION_UPDATE` | `position_update` | 风控模块 → Engine → 订阅者 | 持仓变动 |
| `ACCOUNT_UPDATE` | `account_update` | 风控模块 → Engine → 订阅者 | 账户变动 |

#### position_update payload 示例

```json
{
  "instrument_id": "au2512",
  "exchange": "SHFE",
  "direction": "long",
  "volume": 10,
  "avg_price": 488.50,
  "unrealized_pnl": 125.0
}
```

---

### 风控事件（Risk）

| 常量名 | 事件名 | 广播方向 | 数据格式 |
|--------|--------|---------|---------|
| `RISK_ALERT` | `risk_alert` | 风控模块 → Engine → 订阅者 | 风控警报 |

#### risk_alert payload 示例

```json
{
  "alert_type": "margin_call",
  "module_id": "risk_manager_a1b2c3",
  "message": "Account margin ratio below threshold",
  "severity": "warning",
  "timestamp": 1720000000.789
}
```

---

### 系统事件（System）

| 常量名 | 事件名 | 广播方向 | 数据格式 |
|--------|--------|---------|---------|
| `SYSTEM_CLOCK` | `system_clock` | Engine → 所有模块 | 系统时钟同步 |
| `SYSTEM_SHUTDOWN` | `system_shutdown` | Engine → 所有模块 | 引擎关闭通知 |

#### system_clock payload 示例

```json
{
  "timestamp": 1720000000.0,
  "source": "engine"
}
```

---

## 接口模式（Interface Pattern）

模块通过方法名前缀声明其对某事件的消费/生产关系：

| 前缀 | 模式 | 含义 |
|------|------|------|
| `on_*` | Consumer | 订阅并处理事件（广播） |
| `send_*` | Producer | 发布事件（广播） |
| `handle_*` | Job Handler | 处理请求/响应式 Job |
| `request_*` | Job Requester | 发起请求/响应式 Job |

### 示例

```python
class MyStrategy(TycheModule):
    def on_quote(self, payload):       # 订阅 quote 事件
        ...

    def send_order_submit(self, ...):  # 声明将发布 order_submit 事件
        ...

    def handle_compute_greeks(self, payload):  # 处理 compute_greeks Job
        return {"greeks": {...}}

    def request_static_data(self, ...):  # 发起 static_data Job 请求
        ...
```

## 扩展新事件

添加新事件的步骤：

1. 在 `src/tyche/events.py` 中添加常量定义
2. 在本文档对应章节补充说明和 payload 示例
3. 在消费方模块中实现 `on_*` 处理方法
4. 在生产方模块中实现 `send_*` 声明

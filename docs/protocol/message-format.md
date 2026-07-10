# 消息格式规范（msgpack）

**协议版本**: v1.0  
**源文件**: `src/tyche/message.py`, `src/tyche/cpp/message.h`

---

## 概述

Tyche Engine 的跨语言消息使用 [MessagePack](https://msgpack.org/) 序列化格式。Python 端与 C++ 端产生完全相同的二进制输出，确保互操作性。

- **Python**: `msgpack.packb(data, default=_encode_decimal, use_bin_type=True)`
- **C++**: `msgpack::packer<msgpack::sbuffer>` with `use_bin_type=true`

## Message 结构体

```python
@dataclass
class Message:
    msg_type: MessageType      # 消息类型枚举
    sender: str                # 发送方 module_id
    event: str                 # 事件名称（topic）
    payload: Dict[str, Any]    # 消息负载数据
    recipient: Optional[str]   # 可选目标 module_id
    durability: DurabilityLevel # 持久化级别
    timestamp: Optional[float] # 创建时间戳（Unix 秒）
    correlation_id: Optional[str] # 请求/响应关联 ID
    wait_timeout: Optional[float] # Job 等待超时（秒）
    run_timeout: Optional[float]  # Job 执行超时（秒）
```

C++ 对应结构 (`tyche::Message`)：

```cpp
struct Message {
    MessageType msg_type;
    std::string sender;
    std::string event;
    Payload payload;                    // std::unordered_map<std::string, std::any>
    std::optional<std::string> recipient;
    DurabilityLevel durability;
    std::optional<double> timestamp;
    std::optional<std::string> correlation_id;
    std::optional<float> wait_timeout;
    std::optional<float> run_timeout;
};
```

## 序列化字段顺序

消息序列化为 msgpack map，字段键名固定为以下字符串：

| 字段键名 | 类型 | 必需 | 说明 |
|---------|------|------|------|
| `msg_type` | string | 是 | MessageType 枚举的字符串值 |
| `sender` | string | 是 | 发送方 module_id |
| `event` | string | 是 | 事件名称 |
| `payload` | map | 是 | 消息负载（可为空 map） |
| `recipient` | string/null | 否 | 目标 module_id |
| `durability` | int | 否 | DurabilityLevel 整数值（默认 1） |
| `timestamp` | float/null | 否 | Unix 时间戳 |
| `correlation_id` | string/null | 否 | 请求/响应关联 ID |
| `wait_timeout` | float/null | 否 | Job 等待超时 |
| `run_timeout` | float/null | 否 | Job 执行超时 |

## MessageType 枚举值

| 枚举名 | Python 字符串值 | C++ 字符串值 | 说明 |
|--------|--------------|------------|------|
| COMMAND   | `"cmd"`  | `"cmd"`  | 内部命令 |
| EVENT     | `"evt"`  | `"evt"`  | 普通事件 |
| HEARTBEAT | `"hbt"`  | `"hbt"`  | 心跳消息 |
| REGISTER  | `"reg"`  | `"reg"`  | 注册请求 |
| ACK       | `"ack"`  | `"ack"`  | 注册确认 |
| RESPONSE  | `"resp"` | `"resp"` | Job 响应 |
| REQUEST   | `"req"`  | `"req"`  | Job 请求 |

## DurabilityLevel 枚举值

| 枚举名 | 整数值 | 说明 |
|--------|--------|------|
| BEST_EFFORT | 0 | 无持久化保证 |
| ASYNC_FLUSH | 1 | 异步写入（默认） |
| SYNC_FLUSH  | 2 | 同步写入确认 |

## Decimal 类型特殊处理

Python `decimal.Decimal` 类型使用扩展编码：

```python
# 编码
Decimal("123.45") → {"__decimal__": "123.45"}

# 解码
{"__decimal__": "123.45"} → Decimal("123.45")
```

> **跨语言注意**：C++ 端不原生支持 Decimal，涉及价格的字段在 C++ 中使用 `double`，在 Python 中使用 `Decimal` 时需手动转换。

## Enum 类型处理

Python `enum.Enum` 序列化为其 `.value` 属性：

```python
MessageType.EVENT → "evt"
DurabilityLevel.ASYNC_FLUSH → 1
```

## ZMQ 多帧消息格式

### 事件发布（PUB/SUB）

```
[topic_bytes, msgpack_bytes]
```

- `topic_bytes`: 事件名称的 UTF-8 编码（如 `b"quote"`）
- `msgpack_bytes`: Message 序列化后的字节

### Job 请求/响应（DEALER/ROUTER）

```
[empty_delimiter, topic_bytes, msgpack_bytes]
```

- `empty_delimiter`: `b""` 空帧，标识消息边界
- `topic_bytes`: 事件名称
- `msgpack_bytes`: Message 序列化后的字节

ROUTER 添加 identity 帧后变为：

```
[identity, empty_delimiter, topic_bytes, msgpack_bytes]
```

### 注册握手（REQ/ROUTER）

模块发送：
```
[identity, empty_delimiter, msgpack_bytes]
```

引擎回复：
```
[identity, empty_delimiter, msgpack_bytes(ACK)]
```

## Envelope 序列化

用于 ROUTER 路由的 Envelope 结构：

```python
@dataclass
class Envelope:
    identity: bytes            # ROUTER 分配的客户端身份帧
    message: Message           # 实际消息
    routing_stack: List[bytes] # 路由身份帧栈（用于回复路径）
```

序列化为 ZMQ 多帧：

```
[routing_frame_0, routing_frame_1, ..., b"", identity, msgpack_bytes]
```

## C++ 零分配路径

C++ 提供线程局部存储（TLS）序列化路径，避免堆分配：

```cpp
// 返回 BufferView，有效直到下次 serialize_tls 调用
BufferView serialize_tls(const Message& msg) noexcept;

// 写入调用方提供的缓冲区
size_t serialize_into(const Message& msg, uint8_t* buffer, size_t capacity) noexcept;
```

> **热路径推荐**：高频事件发布场景使用 `serialize_tls` 以获得最佳性能。

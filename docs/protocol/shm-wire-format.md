# 共享内存线格式（SHM Wire Format）

**协议版本**: v1.0  
**源文件**: `src/tyche/cpp/flat_message.h`, `src/tyche/cpp/flat_serializer.h`, `src/tyche/cpp/string_intern.h`

---

## 概述

共享内存（SHM）通道专用于 **C++ 模块间** 的高性能通信，绕过 msgpack 序列化开销。跨语言通信（C++ ↔ Python）仍然使用 msgpack。

设计目标：
- **零堆分配**：热路径上无任何 `malloc`/`new`
- **缓存行对齐**：64 字节对齐，适配现代 CPU 缓存行
- **memcpy 级序列化**：直接内存拷贝，无编解码过程
- **零拷贝反序列化**：直接指针转换，无数据复制

## FlatMessageHeader（24 字节）

通用变长消息的二进制头部，采用 `#pragma pack(push, 1)` 紧凑打包：

```
┌─────────────────────────────────────────────────┐
│ 字段             │ 类型      │ 大小  │ 偏移     │
├──────────────────┼───────────┼───────┼──────────┤
│ msg_type         │ uint8_t   │ 1 B   │ 0        │
│ durability       │ uint8_t   │ 1 B   │ 1        │
│ sender_len       │ uint16_t  │ 2 B   │ 2        │
│ event_len        │ uint16_t  │ 2 B   │ 4        │
│ payload_len      │ uint16_t  │ 2 B   │ 6        │
│ total_size       │ uint32_t  │ 4 B   │ 8        │
│ timestamp        │ double    │ 8 B   │ 12       │
│ _pad             │ uint8_t[] │ 4 B   │ 20       │
└─────────────────────────────────────────────────┘
Total: 24 bytes (padded for 8-byte alignment)
```

### 内存布局

头部之后紧跟变长数据区域：

```
[FlatMessageHeader: 24 bytes]
[sender bytes: sender_len]
[event bytes: event_len]
[payload bytes: payload_len]
```

访问方式（零拷贝）：

```cpp
const FlatMessageHeader* hdr = reinterpret_cast<const FlatMessageHeader*>(buffer);
const uint8_t* sender_data = hdr->sender_data();    // 紧跟 header 之后
const uint8_t* event_data  = hdr->event_data();     // sender_data + sender_len
const uint8_t* payload_data = hdr->payload_data();  // event_data + event_len
```

## FlatQuoteTick（72 字节 + 对齐填充）

固定布局的行情 tick 消息，专为 CTP 期权行情热路径设计：

```
┌─────────────────────────────────────────────────────┐
│ 字段             │ 类型      │ 大小  │ 偏移        │
├──────────────────┼───────────┼───────┼─────────────┤
│ symbol           │ char[16]  │ 16 B  │ 0           │
│ bid              │ double    │ 8 B   │ 16          │
│ ask              │ double    │ 8 B   │ 24          │
│ last             │ double    │ 8 B   │ 32          │
│ volume           │ int64_t   │ 8 B   │ 40          │
│ timestamp        │ double    │ 8 B   │ 48          │
│ local_ts         │ double    │ 8 B   │ 56          │
│ tick_count       │ uint32_t  │ 4 B   │ 64          │
│ flags            │ uint8_t   │ 1 B   │ 68          │
│ _pad             │ uint8_t[] │ 3 B   │ 69          │
└─────────────────────────────────────────────────────┘
Total: 72 bytes (FlatQuoteTickData)
```

### 缓存行对齐包装

`FlatQuoteTick` 是带有 `alignas(64)` 的包装结构：

```cpp
struct alignas(64) FlatQuoteTick {
    FlatQuoteTickData data;      // 72 bytes
    uint8_t _align_pad[56];     // 填充至 128 bytes（2 条缓存行）
};

static_assert(sizeof(FlatQuoteTick) == 128);
static_assert(alignof(FlatQuoteTick) == 64);
```

### flags 位域

| 位 | 掩码 | 含义 |
|----|------|------|
| bit0 | `0x01` | IS_OPTION — 期权合约 |
| bit1 | `0x02` | IS_STALE — tick 已过期（交易所超时） |

```cpp
// 读取标志
bool is_option = (tick.flags() & FlatQuoteFlags::IS_OPTION) != 0;
bool is_stale  = (tick.flags() & FlatQuoteFlags::IS_STALE)  != 0;

// 设置标志
FlatQuoteFlags::set_option(tick);
FlatQuoteFlags::set_stale(tick);
```

## 序列化 API

### FlatMessage 序列化

```cpp
// 写入调用方缓冲区，返回写入字节数；溢出返回 0
size_t serialize_flat(const Message& msg, uint8_t* buffer, size_t capacity) noexcept;

// 从原始字节反序列化（payload 存为 __flat__ 键的原始字节）
Message deserialize_flat(const uint8_t* data, size_t size) noexcept;
```

### FlatQuoteTick 序列化

```cpp
// 直接 memcpy 到缓冲区
size_t serialize_flat_quote(const FlatQuoteTick& tick, uint8_t* buffer, size_t capacity) noexcept;

// 零拷贝反序列化（直接指针转换，要求内存对齐）
const FlatQuoteTick* deserialize_flat_quote(const uint8_t* data, size_t size) noexcept;
```

> **对齐要求**：`deserialize_flat_quote` 要求 `data` 指针满足 `alignof(FlatQuoteTickData)` 对齐，否则返回 `nullptr`。

## Flat Payload 编码格式

`serialize_flat` 中 payload 区域使用简化的二进制编码（非 msgpack）：

```
[uint32_t map_size]                     // payload 条目数
[uint32_t key_len][key bytes]           // 键名
[uint8_t type_marker][value bytes]      // 类型标记 + 值
...重复...
```

### 类型标记

| 标记值 | 类型 | 值大小 |
|--------|------|--------|
| `0x00` | nil | 0 B |
| `0x01` | string | `[uint32_t len][bytes]` |
| `0x02` | double | 8 B |
| `0x03` | int32 | 4 B |
| `0x04` | int64 | 8 B |
| `0x05` | uint64 | 8 B |
| `0x06` | float | 4 B |
| `0x07` | bool | 1 B（0 或 1） |

## 共享内存队列协议

SHM 队列通过命名共享内存实现生产者-消费者模式：

```json
{
  "shm_queue_name": "tyche_shm_example",
  "slot_count": 2048,
  "max_msg_size": 4096
}
```

- `slot_count`：环形缓冲区槽位数（推荐范围：64 ~ 65536）
- `max_msg_size`：单条消息最大字节数（推荐范围：256 ~ 1MB）

### SHM Bridge 配置

将 SHM 队列桥接到 ZMQ topic：

```json
{
  "shm_queue_name": "tyche_shm_external",
  "zmq_topic": "market_data",
  "slot_count": 2048,
  "max_msg_size": 4096
}
```

## 字符串驻留（String Interning）

为消除热路径上的字符串比较开销，使用 `StringIntern` 将 topic/module ID 映射为 `uint32_t`：

```cpp
tyche::StringIntern interner;
tyche::InternId id = interner.intern("quote");       // 分配 ID
tyche::InternId same = interner.lookup("quote");     // 查找已有 ID
std::string_view sv = interner.resolve(id);          // 反向解析
```

- **线程安全**：多线程可并发调用 `intern()` 和 `lookup()`
- **ID 0 保留**：`INVALID_INTERN_ID = 0` 表示未找到

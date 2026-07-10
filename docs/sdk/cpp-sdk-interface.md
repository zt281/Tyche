# C++ SDK 接口规范

**版本**: v1.0  
**包名**: `tyche-cpp-sdk`（静态库 `tyche_module`）

---

## 概述

`tyche-cpp-sdk` 提供 C++ 模块接入 Tyche Engine 所需的全部基础设施，包括类型定义、消息序列化、模块生命周期管理和高性能 flat message 格式。

以 CMake `FetchContent` 或子模块方式引入后，网关/策略模块可直接使用公共头文件。

## 公共头文件清单

以下头文件构成 C++ SDK 的稳定公共接口，任何破坏性变更需递增主版本号。

### `include/tyche/types.h`

核心类型定义，镜像 `src/tyche/types.py`。

```cpp
#include <tyche/types.h>

// 常量
tyche::HEARTBEAT_INTERVAL    // 1.0 秒
tyche::HEARTBEAT_LIVENESS    // 3 次未响应视为离线
tyche::ADMIN_PORT_DEFAULT    // 5558

// 枚举
tyche::EventType             // REQUEST, RESPONSE, EVENT, HEARTBEAT, REGISTER, ACK
tyche::InterfacePattern      // ON, SEND, HANDLE, REQUEST
tyche::BackpressureStrategy  // DROP_OLDEST, DROP_NEWEST, BLOCK_PRODUCER
tyche::DurabilityLevel       // BEST_EFFORT=0, ASYNC_FLUSH=1, SYNC_FLUSH=2
tyche::MessageType           // COMMAND, EVENT, HEARTBEAT, REGISTER, ACK, RESPONSE, REQUEST

// 结构体
tyche::Payload               // std::unordered_map<std::string, std::any>
tyche::Endpoint              // {host, port} → to_string() 返回 "tcp://host:port"
tyche::Interface             // {name, pattern, event_type, durability, backpressure, max_queue_depth}
tyche::ModuleInfo            // {module_id, interfaces[], metadata}

// ModuleId 工具
tyche::ModuleId::generate("my_family")  // 返回 "my_family_a1b2c3"

// 字符串转换
tyche::message_type_to_str(MessageType::EVENT)     // → "evt"
tyche::message_type_from_str("evt")                // → MessageType::EVENT
tyche::interface_pattern_to_str(InterfacePattern::ON) // → "on"
tyche::interface_pattern_from_str("on")            // → InterfacePattern::ON
```

### `include/tyche/message.h`

消息序列化接口，与 Python `msgpack` 格式二进制兼容。

```cpp
#include <tyche/message.h>

// 消息结构体
tyche::Message msg;
msg.msg_type = tyche::MessageType::EVENT;
msg.sender   = "gateway_abc123";
msg.event    = "quote";
msg.payload  = {{"instrument_id", std::string("au2512")}, {"price", 488.5}};

// 标准序列化（堆分配）
std::vector<uint8_t> bytes = tyche::serialize(msg);
tyche::Message restored = tyche::deserialize(bytes.data(), bytes.size());

// TLS 零分配序列化（热路径推荐）
tyche::BufferView view = tyche::serialize_tls(msg);  // 有效至下一次调用
// 写入调用方缓冲区
uint8_t buf[4096];
size_t n = tyche::serialize_into(msg, buf, sizeof(buf));

// 高级：payload 打包/解包
tyche::pack_any(packer, std::any(std::string("hello")));
std::any value = tyche::unpack_object(obj);
```

### `include/tyche/module.h`

模块生命周期管理（注册、事件订阅、心跳、Job 通信）。

```cpp
#include <tyche/module.h>

// 创建并启动模块
tyche::TycheModule module("my_gateway", endpoint);
module.add_interface({"on_quote", tyche::InterfacePattern::ON, "quote"});
module.add_interface({"send_order_submit", tyche::InterfacePattern::SEND, "order_submit"});
module.start();   // 注册 + 连接 + 启动工作线程
module.stop();    // 优雅停止
```

### `include/tyche/flat_message.h`

零拷贝二进制消息格式，仅用于 C++ 模块间通信。

```cpp
#include <tyche/flat_message.h>

// FlatMessageHeader（24 bytes）
tyche::FlatMessageHeader hdr;
hdr.msg_type   = static_cast<uint8_t>(tyche::MessageType::EVENT);
hdr.sender_len = sender.size();
hdr.event_len  = event.size();
// ... 访问变长数据区
const uint8_t* s = hdr.sender_data();
const uint8_t* e = hdr.event_data();

// FlatQuoteTick（128 bytes，64-byte 对齐）
tyche::FlatQuoteTick tick;
std::strncpy(tick.symbol(), "au2512", 16);
tick.bid() = 488.50;
tick.ask() = 488.60;
tick.last() = 488.55;
tick.volume() = 12345;
tick.flags() |= tyche::FlatQuoteFlags::IS_OPTION;
```

### `include/tyche/flat_serializer.h`

Flat message 序列化/反序列化工具。

```cpp
#include <tyche/flat_serializer.h>

// 序列化 Message → flat bytes（无堆分配）
uint8_t buf[4096];
size_t n = tyche::serialize_flat(msg, buf, sizeof(buf));

// 反序列化 flat bytes → Message
tyche::Message restored = tyche::deserialize_flat(buf, n);

// 序列化 FlatQuoteTick（直接 memcpy）
uint8_t qbuf[128];
size_t qn = tyche::serialize_flat_quote(tick, qbuf, sizeof(qbuf));

// 零拷贝反序列化（要求指针对齐）
const tyche::FlatQuoteTick* q = tyche::deserialize_flat_quote(qbuf, qn);
```

### `include/tyche/string_intern.h`

字符串驻留服务，将字符串映射为 `uint32_t` ID，消除热路径上的字符串比较。

```cpp
#include <tyche/string_intern.h>

tyche::StringIntern interner;

tyche::InternId id  = interner.intern("quote");       // 分配或返回已有 ID
tyche::InternId id2 = interner.lookup("quote");       // 仅查找（不分配）
std::string_view sv = interner.resolve(id);           // 反向解析

// 线程安全，可并发调用
// INVALID_INTERN_ID (= 0) 表示未找到
```

## CTP 网关集成示例

CTP 网关模块通过 CMake 链接 `tyche_module` 静态库：

```cmake
add_library(ctp_gateway_cpp SHARED
    src/ctp_gateway.cpp
    src/md_spi.cpp
    src/td_spi.cpp
)

target_link_libraries(ctp_gateway_cpp PRIVATE tyche_module)
target_include_directories(ctp_gateway_cpp PRIVATE
    ${TYCHE_CPP_SDK_INCLUDE_DIR}
)
```

源码中引用：

```cpp
#include <tyche/types.h>
#include <tyche/message.h>
#include <tyche/module.h>
```

## 版本兼容性规则

| 变更类型 | 版本号影响 | 示例 |
|---------|----------|------|
| 新增公共头文件/函数 | 次版本 +1 | 新增 `tyche/metrics.h` |
| 新增枚举值 | 次版本 +1 | MessageType 新增 `BATCH` |
| 修改现有结构体字段 | 主版本 +1 | Message 字段删除或类型变更 |
| 修改 flat message 布局 | 主版本 +1 | FlatMessageHeader 字段变更 |
| 修改 msgpack 序列化格式 | 主版本 +1 | 字段键名变更 |
| 修复 Bug（不改变接口） | 修订号 +1 | 内存泄漏修复 |

## 编译要求

- **C++ 标准**: C++17 或更高
- **依赖**:
  - `msgpack-c` ≥ 3.0
  - `cppzmq` ≥ 4.8（header-only）
  - `libzmq` ≥ 4.3
  - `nlohmann_json`（header-only）
- **编译器**:
  - MSVC 2019+（Windows）
  - GCC 9+（Linux）
  - Clang 12+（macOS）

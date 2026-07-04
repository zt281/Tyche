// Unit tests for common C++ module SHM transport helpers.

#include <gtest/gtest.h>

#include <chrono>
#include <cstdint>
#include <string>
#include <vector>

#include "tyche/cpp/engine/shared_memory_queue.h"
#include "tyche/cpp/message.h"
#include "tyche/cpp/module.h"

namespace tyche {
namespace {

class TestModule : public TycheModule {
public:
    TestModule() : TycheModule(Endpoint{"127.0.0.1", 1}, "test_cpp_module") {}

    using TycheModule::has_shared_memory_queue;
    using TycheModule::open_shared_memory_queue;
    using TycheModule::send_event_shared_memory;
    using TycheModule::set_shared_memory_queue;
};

std::string unique_queue_name(const char* prefix) {
    const auto ticks = std::chrono::steady_clock::now()
                           .time_since_epoch()
                           .count();
    return std::string(prefix) + "_" + std::to_string(ticks);
}

Message read_wire_message(SharedMemoryQueue& queue, std::string& topic) {
    std::vector<uint8_t> buffer(4096);
    size_t msg_size = 0;
    EXPECT_TRUE(queue.read_into(buffer.data(), buffer.size(), msg_size));
    EXPECT_GE(msg_size, 2u);

    const auto topic_len =
        static_cast<uint16_t>(buffer[0]) |
        static_cast<uint16_t>(buffer[1] << 8);
    EXPECT_GE(msg_size, static_cast<size_t>(2 + topic_len));

    topic.assign(reinterpret_cast<const char*>(buffer.data() + 2), topic_len);
    return deserialize(buffer.data() + 2 + topic_len, msg_size - 2 - topic_len);
}

TEST(ModuleTransportTest, WritesSharedMemoryEventWithTycheWireFormat) {
    SharedMemoryQueue owner(
        SharedMemoryQueue::Config{unique_queue_name("module_transport_write"), 64, 4096},
        true);
    ASSERT_TRUE(owner.is_valid());

    TestModule module;
    module.set_shared_memory_queue(&owner);
    ASSERT_TRUE(module.has_shared_memory_queue());

    Payload payload;
    payload["instrument_id"] = std::string("ag2608");
    payload["last_price"] = 123.45;

    EXPECT_TRUE(module.send_event_shared_memory("quote", payload));

    std::string topic;
    Message msg = read_wire_message(owner, topic);
    EXPECT_EQ(topic, "quote");
    EXPECT_EQ(msg.msg_type, MessageType::EVENT);
    EXPECT_EQ(msg.sender, "test_cpp_module");
    EXPECT_EQ(msg.event, "quote");
    EXPECT_EQ(std::any_cast<std::string>(msg.payload.at("instrument_id")), "ag2608");
    EXPECT_DOUBLE_EQ(std::any_cast<double>(msg.payload.at("last_price")), 123.45);
}

TEST(ModuleTransportTest, OpensConfiguredSharedMemoryQueue) {
    const auto queue_name = unique_queue_name("module_transport_open");
    SharedMemoryQueue owner(SharedMemoryQueue::Config{queue_name, 64, 4096}, true);
    ASSERT_TRUE(owner.is_valid());

    TestModule module;
    EXPECT_TRUE(module.open_shared_memory_queue(
        ModuleSharedMemoryQueueConfig{queue_name, 64, 4096}, false));
    ASSERT_TRUE(module.has_shared_memory_queue());

    Payload payload;
    payload["status"] = std::string("ok");
    EXPECT_TRUE(module.send_event_shared_memory("health", payload));

    std::string topic;
    Message msg = read_wire_message(owner, topic);
    EXPECT_EQ(topic, "health");
    EXPECT_EQ(std::any_cast<std::string>(msg.payload.at("status")), "ok");
}

}  // namespace
}  // namespace tyche

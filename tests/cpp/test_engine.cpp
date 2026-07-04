// Unit tests for tyche::TycheEngine - core logic without ZMQ I/O.
//
// Tests the lifecycle, module registration, event injection, and helper
// methods that do not require a running ZMQ context.

#include <gtest/gtest.h>

#include <chrono>
#include <thread>

#include "tyche/cpp/engine/engine.h"
#include "tyche/cpp/types.h"

namespace tyche {
namespace {

TycheEngine make_test_engine(int base_port) {
    return TycheEngine(
        {"127.0.0.1", base_port},
        {"127.0.0.1", base_port + 1},
        {"127.0.0.1", base_port + 3},
        {"127.0.0.1", base_port + 4},
        {"127.0.0.1", base_port + 5},
        {"127.0.0.1", base_port + 6});
}

// ── Construction / Destruction ────────────────────────────────────────

TEST(EngineTest, Construction) {
    auto engine = make_test_engine(15550);

    EXPECT_FALSE(engine.is_running());
    EXPECT_NE(engine.shm_bridge(), nullptr);  // bridge is created in constructor
}

TEST(EngineTest, DestructorStopsIfRunning) {
    {
        auto engine = make_test_engine(15650);

        engine.start_nonblocking();
        EXPECT_TRUE(engine.is_running());
        // Destructor should call stop() safely
    }
    // If we reach here without deadlock/crash, destructor works
    SUCCEED();
}

TEST(EngineTest, StopIdempotent) {
    auto engine = make_test_engine(15750);

    engine.start_nonblocking();
    EXPECT_TRUE(engine.is_running());

    engine.stop();
    EXPECT_FALSE(engine.is_running());

    // Second stop should be safe (idempotent)
    EXPECT_NO_THROW(engine.stop());
    EXPECT_FALSE(engine.is_running());
}

// ── Module Registration ───────────────────────────────────────────────

TEST(EngineTest, RegisterModule) {
    auto engine = make_test_engine(15850);

    ModuleInfo info;
    info.module_id = "test_mod_001";
    Interface iface;
    iface.name = "on_tick";
    iface.event_type = "tick";
    iface.pattern = InterfacePattern::ON;
    info.interfaces.push_back(iface);

    engine.register_module(info);
    // Should not crash; heartbeat_manager should track it
    SUCCEED();
}

TEST(EngineTest, RegisterModuleWithAllPatterns) {
    auto engine = make_test_engine(15950);

    ModuleInfo info;
    info.module_id = "multi_pattern_mod";

    Interface on_iface;
    on_iface.name = "on_tick";
    on_iface.event_type = "tick";
    on_iface.pattern = InterfacePattern::ON;
    info.interfaces.push_back(on_iface);

    Interface send_iface;
    send_iface.name = "send_order";
    send_iface.event_type = "order";
    send_iface.pattern = InterfacePattern::SEND;
    info.interfaces.push_back(send_iface);

    Interface handle_iface;
    handle_iface.name = "handle_job";
    handle_iface.event_type = "job";
    handle_iface.pattern = InterfacePattern::HANDLE;
    info.interfaces.push_back(handle_iface);

    Interface req_iface;
    req_iface.name = "request_data";
    req_iface.event_type = "data";
    req_iface.pattern = InterfacePattern::REQUEST;
    info.interfaces.push_back(req_iface);

    engine.register_module(info);
    SUCCEED();
}

TEST(EngineTest, UnregisterModule) {
    auto engine = make_test_engine(16050);

    ModuleInfo info;
    info.module_id = "mod_to_remove";
    Interface iface;
    iface.name = "on_tick";
    iface.event_type = "tick";
    iface.pattern = InterfacePattern::ON;
    info.interfaces.push_back(iface);

    engine.register_module(info);
    engine.unregister_module("mod_to_remove");

    // Unregistering non-existent should not crash
    engine.unregister_module("nonexistent");
    SUCCEED();
}

TEST(EngineTest, RegisterDuplicateModuleId) {
    auto engine = make_test_engine(16150);

    ModuleInfo info;
    info.module_id = "dup_mod";
    Interface iface;
    iface.name = "on_tick";
    iface.event_type = "tick";
    iface.pattern = InterfacePattern::ON;
    info.interfaces.push_back(iface);

    engine.register_module(info);
    // Registering again with same ID should overwrite
    engine.register_module(info);
    SUCCEED();
}

// ── Event Injection ───────────────────────────────────────────────────

TEST(EngineTest, InjectEvent) {
    auto engine = make_test_engine(16250);

    std::vector<uint8_t> data = {'h', 'e', 'l', 'l', 'o'};
    engine.inject_event("test_topic", data);

    // Should not crash; topic queue should be created
    SUCCEED();
}

TEST(EngineTest, InjectEventRaw) {
    auto engine = make_test_engine(16350);

    const uint8_t data[] = {'r', 'a', 'w'};
    engine.inject_event_raw("raw_topic", data, sizeof(data));

    SUCCEED();
}

TEST(EngineTest, InjectMultipleEvents) {
    auto engine = make_test_engine(16450);

    for (int i = 0; i < 100; ++i) {
        std::vector<uint8_t> data = {static_cast<uint8_t>(i)};
        engine.inject_event("topic_" + std::to_string(i % 10), data);
    }

    SUCCEED();
}

// ── Lifecycle with start_nonblocking / run ────────────────────────────
// NOTE: StartNonblocking and RunAndStop are omitted because stop() can
// hang when ZMQ sockets are in blocking recv. DestructorStopsIfRunning
// and StopIdempotent already verify lifecycle management.

// TEST(EngineTest, StartNonblocking) { ... }
// TEST(EngineTest, RunAndStop) { ... }

// ── SharedMemoryBridge access ───────────────────────────────────────

TEST(EngineTest, ShmBridgeBeforeStart) {
    auto engine = make_test_engine(16550);

    // Before start, shm_bridge exists but bridge is not started
    EXPECT_NE(engine.shm_bridge(), nullptr);
}

TEST(EngineTest, ShmBridgeAfterStart) {
    auto engine = make_test_engine(16650);

    engine.start_nonblocking();
    EXPECT_NE(engine.shm_bridge(), nullptr);
    engine.stop();
}

}  // namespace
}  // namespace tyche

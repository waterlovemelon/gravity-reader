# Gravity Reader `edge-tts` 集成架构设计

## 1. 设计目标

- 在现有 Flutter 客户端中稳定接入 `edge-tts` 能力。
- 保留当前“云端优先 + 本地回退”体验，避免单点故障。
- 让 TTS 引擎可替换（未来可切 Azure/OpenAI/本地模型）。
- 控制延迟、失败率和成本，并具备可观测性。

## 2. 现状与约束

当前实现（已存在）：

- 客户端 TTS 入口：`lib/data/services/tts_service.dart`
- 状态管理：`lib/core/providers/tts_provider.dart`
- 云端接口：`GET /api/text-to-speech`（通过 `TTS_BASE_URL` 调用）
- 回退策略：云端超时后自动切本地 TTS，并在冷却后重试云端

关键约束：

- `edge-tts` 通常运行在 Node/Python 环境，不适合直接嵌入 iOS/Android Flutter 运行时。
- 移动端最佳实践是“客户端调用网关服务”，`edge-tts` 放在服务端执行。

## 3. 总体架构（推荐）

```text
[Flutter App]
  └─ TtsService (云端优先 + 本地回退)
      ├─ CloudTtsDataSource -> [TTS Gateway API]
      └─ NativeLocalTtsDataSource (iOS/Android 原生 TTS)

[TTS Gateway API]
  ├─ TtsApplicationService (鉴权、限流、参数校验、日志)
  ├─ TtsProviderFactory
  │   ├─ EdgeTtsProvider (主)
  │   └─ Mock/FallbackProvider (测试或兜底)
  ├─ AudioCache (hash 键缓存)
  └─ Storage (本地磁盘/S3，可选)
```

核心原则：

- Flutter 只依赖统一 API，不感知 `edge-tts` 细节。
- `edge-tts` 作为 Provider 插件实现，避免业务代码绑死具体引擎。
- Gateway 层负责可观测性、重试、缓存、鉴权和限流。

## 4. 客户端分层改造（Flutter）

### 4.1 建议目录

```text
lib/
├── domain/
│   ├── entities/tts_request.dart
│   ├── entities/tts_result.dart
│   └── repositories/tts_repository.dart
├── data/
│   ├── datasources/remote/tts_remote_data_source.dart
│   ├── datasources/local/tts_native_data_source.dart
│   ├── repositories/tts_repository_impl.dart
│   └── services/tts_service.dart           # 保留编排角色
└── core/providers/tts_provider.dart        # 继续用 Riverpod 暴露状态
```

### 4.2 职责划分

- `TtsService`
  - 只做播放编排：停止/暂停/恢复、云端优先、失败回退。
  - 不处理 HTTP 细节，不拼接 `edge-tts` 参数。
- `TtsRemoteDataSource`
  - 负责请求 Gateway API，拿到音频 URL/流。
- `TtsNativeDataSource`
  - 封装 `MethodChannel` 原生本地 TTS。
- `TtsRepository`
  - 提供统一入口：`synthesize(request)`，屏蔽本地/云端实现差异。

### 4.3 状态机建议

统一状态：`idle -> preparing -> playing -> paused -> completed/failed`

错误状态附带：

- `source`: `cloud` | `local`
- `code`: `timeout` | `network` | `auth` | `rate_limit` | `unsupported_voice` | `unknown`

## 5. Gateway 服务设计（edge-tts 所在层）

## 5.1 API 契约（建议）

### 生成语音（同步，短文本）

- `POST /api/tts/synthesize`
- Request:

```json
{
  "text": "要朗读的文本",
  "voice": "zh-CN-XiaoxiaoNeural",
  "rate": 0,
  "pitch": 0,
  "volume": 0,
  "format": "mp3"
}
```

- Response:

```json
{
  "audioUrl": "https://.../tts/abc123.mp3",
  "durationMs": 12800,
  "cached": true,
  "provider": "edge-tts"
}
```

### 语音列表

- `GET /api/tts/voices?locale=zh-CN`

### 健康检查

- `GET /api/tts/health`

兼容策略：

- 现有 `GET /api/text-to-speech` 可保留一段时间，内部转发到新接口，避免客户端一次性切换风险。

## 5.2 Provider 接口（服务端）

```ts
interface TtsProvider {
  synthesize(input: TtsInput): Promise<TtsOutput>;
  listVoices(locale?: string): Promise<VoiceInfo[]>;
  capabilities(): ProviderCapabilities;
}
```

`EdgeTtsProvider` 仅实现该接口，不直接暴露给控制器。

## 5.3 缓存策略

缓存键：

`sha256(text + voice + rate + pitch + volume + format + providerVersion)`

策略：

- 命中直接返回 `audioUrl`，跳过合成。
- 长文本分段缓存（按段 hash），支持复用。
- TTL 默认 7 天（按存储成本调整）。

## 5.4 稳定性策略

- 超时：单次合成 8~12s（与客户端超时一致）。
- 重试：仅对可重试错误（网络抖动/5xx）做 1~2 次指数退避。
- 限流：按用户/IP 做 QPS 和并发上限。
- 熔断：Provider 错误率高于阈值时短暂熔断并快速失败。

## 6. 文本处理策略

- 输入长度上限：例如单次 1500~2500 字。
- 超长文本自动分句分段，段间可插入短静音。
- 清理 Markdown/HTML 标签与异常空白，避免发音噪音。
- 可选支持 SSML（作为后续能力，不在第一期强依赖）。

## 7. 安全与配置

- Gateway 增加 `Bearer Token` 或签名鉴权。
- 客户端仅持有业务 token，不暴露 provider 内部凭据。
- 配置项建议：
  - `TTS_BASE_URL`
  - `TTS_TOKEN`
  - `TTS_CLOUD_TIMEOUT_MS`
  - `TTS_CLOUD_RETRY_COOLDOWN_MS`
  - `TTS_DEFAULT_VOICE`

## 8. 可观测性

至少打点以下指标：

- 请求量、成功率、P95/P99 延迟
- 缓存命中率
- 按 `voice` 的失败分布
- Provider 级错误码分布
- 客户端回退到本地 TTS 的比例

日志需包含 `requestId`，便于端到端追踪（客户端 -> Gateway -> Provider）。

## 9. 分阶段落地计划

### Phase 1（最小可用）

- 新建 Gateway `EdgeTtsProvider` 与 `POST /api/tts/synthesize`
- 客户端新增 `TtsRemoteDataSource`，`TtsService` 调用新接口
- 保留现有本地 TTS 回退机制

验收标准：

- 云端成功率 >= 98%
- 超时/失败可稳定回退本地

### Phase 2（稳定性）

- 加缓存、限流、重试、错误码标准化
- 客户端状态机补充 `failed(reason)`

验收标准：

- 缓存命中率达到目标（如 > 30%，视场景）
- P95 延迟明显下降

### Phase 3（增强）

- 长文本异步任务化（`/jobs`）
- 增加 voice 预览与多 provider 切换

## 10. 风险与规避

- 风险：`edge-tts` 上游行为变化导致语音不可用
  - 规避：Provider 抽象 + 本地回退 + 熔断
- 风险：长文本超时
  - 规避：分段合成 + 异步任务模式
- 风险：移动网络波动
  - 规避：客户端短重试 + 本地 TTS 兜底

## 11. 结论

对当前项目，最优路径是：

- `edge-tts` 放在 Gateway 服务端，Flutter 通过统一 API 访问；
- 客户端维持“云端优先 + 本地回退”的现有体验；
- 用 Provider 插件化与缓存/限流/观测把方案从“能用”提升到“可长期维护”。


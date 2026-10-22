## CTX-local-decision-models — 本地决策模型选择
- Scope: 设置中的Laya/Vela/Local LLM选择、模型部署与服务、Pi回答结束hook的用户参与分类。
- Paths: `iTermate/LocalModelService.swift`, `integrations/laya/`, `integrations/pi/iTermate-integration.ts`, `iTermateBridge/iTermateBridge.py`, `docs/local-model-api.md`
- Keywords: Laya, Vela, Ollama, Qwen, Local LLM, decision model, provider, question, local model, epoch
- Authority: `iTermate/LocalModelService.swift`, `integrations/laya/iTermate-laya.py`, `integrations/pi/iTermate-integration.ts`, `iTermateBridge/iTermateBridge.py`
- Recheck: provider选择、安装目录、控制协议、问句定义、推理结果合并或服务生命周期变化时复查。

### Structure
- `LocalModelService`拥有单个所选分类worker、持久偏好及设置入口；沿用Laya控制目录，Vela与Local LLM各有独立运行时和部署标记。Python helper承载统一鉴权API和provider适配，固定模型版本与校验来源以helper/Swift枚举为准，不缓存到Context。
- Local LLM通过固定回环Ollama使用Qwen 2B；App只管理自己的Python分类桥接，不自动安装、启动、停止Ollama或卸载其共享缓存。部署复用匹配的既有模型，缺失时经Ollama下载，并校验模型digest；新设置区的库存可用与分类桥接Ready为不同状态。
- 配置revision、ready分析许可及端点provider/instance共同绑定推理身份；Pi响应校验身份，拒绝切换后的旧结果。新模型不可用不会自动切回另一模型；默认选择Vela，有效持久化选择保持优先。

### Decision and Verification Boundaries
- 产品仅在Pi回答结束的agent_settled hook分析最新完整回复；请求确认、选择、授权或信息以及隐含确认门均视为需要用户参与，不要求疑问句。Bridge不抓取屏幕或轮询模型；无对应hook的会话不做模型猜测。等待结果由心跳续租，心跳不推理；原生finished作为未读idle标记显示高亮，点击灰显。模型判断不构成安全授权。
- Local LLM只开放固定question/session分类，不支持通用decide；生成式结果不提供或伪造概率，Pi按provider核验source和合法标签，旧提供方保留概率校验。LLM的请求截止独立于小型分类器，并先预热后发布许可；失败保留生命周期，不静默换模型或云端。此选择不改变标题生成的当前Pi模型。
- 源码和构建通过不代表用户已运行新App或重新加载Pi集成；安装、启动和真实切换验收与源码交付区分。

# Plano de Desenvolvimento - Rinha de Backend 2025 Zig

## Objetivo
Implementar proxy de pagamentos em Zig para superar o top 1 (Rust) com:
- Performance sub-1ms (p99 < 1ms para bônus máximo 20%)
- Máximo lucro (foco no payment-processor-default)
- Arquitetura: HAProxy + 2 Gateways + Storage compartilhado

## Fase 1: Base Sólida ✅ CONCLUÍDA
1. ✅ HTTP server básico em Zig
2. ✅ JSON parsing otimizado 
3. ✅ Client HTTP para payment processors
4. ✅ Estrutura básica de dados em memória

**Status:** Servidor funcional com endpoints /payments e /payments-summary

## Fase 2: Otimizações Core 🟡 PARCIALMENTE FEITA
1. ✅ Unix Domain Sockets
2. ✅ Arena allocators  
3. ✅ Lock-free queues
4. ✅ Worker pool pattern

**Problemas descobertos:**
- ❌ Falta HAProxy para load balancing
- ❌ Estado não compartilhado entre instâncias
- ❌ Storage distribuído (payments-summary inconsistente)
- ❌ Não testamos com payment processors reais

**Próximos passos:**
1. **HAProxy config** para 2 instâncias
2. **Storage compartilhado** (banco separado como top 1)
3. **Estado compartilhado** via Unix socket/mmap
4. **Teste integração** com payment processors

## Fase 3: Performance Extrema ❌ NÃO INICIADA
1. ❌ io_uring integration
2. ❌ SIMD optimizations
3. ❌ Zero-copy paths
4. ❌ Profiling e tuning

**Target:** p99 < 1ms para bônus máximo

## Fase 4: Inteligência de Negócio 🟡 PARCIALMENTE FEITA
1. 🟡 Health check caching (implementamos performance-based)
2. ❌ Circuit breaker
3. ❌ Adaptive batching  
4. ❌ Performance monitoring

**Estratégia inspirada no top 1:**
- Performance-based detection (sem health check endpoint)
- Master + Slave worker pattern
- Foco total no processor default

## Arquitetura Alvo

```
┌─────────────┐ unix sock ┌─────────────┐ unix sock ┌─────────────┐
│   HAProxy   │───────────│  Gateway 1  │───────────│             │
│             │           │   (Zig)     │           │   Shared    │
│ round-robin │ unix sock ┌─────────────┐ unix sock │   Storage   │
│             │───────────│  Gateway 2  │───────────│   (Zig)     │
└─────────────┘           │   (Zig)     │           │ Unix Socket │
                          └─────────────┘           └─────────────┘
```

## Estratégia de Performance (baseada no top 1)
- **Sem health check endpoint** (evita limite 5s)
- **Detecção por latência real** de cada request
- **Master worker:** processa sempre, mede performance  
- **Slave workers:** ativam quando latência <= trigger (200ms)
- **Estado compartilhado** via atomic operations
- **Burst mode:** todos workers quando performance boa

## Status Atual
- ✅ Server HTTP funcional
- ✅ Worker pattern implementado
- ✅ Performance-based detection
- ❌ HAProxy config
- ❌ Storage compartilhado  
- ❌ Estado compartilhado entre instâncias
- ❌ Integração com payment processors reais

## Próximo Passo
**Completar Fase 2:** Focar em HAProxy + Storage compartilhado para resolver problema de consistência entre instâncias.
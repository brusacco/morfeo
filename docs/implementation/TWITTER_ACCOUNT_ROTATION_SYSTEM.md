# Twitter Account Rotation System

**Fecha**: Noviembre 7, 2025  
**Estado**: ✅ Implementado  
**Versión**: 1.0

---

## 📋 Resumen Ejecutivo

Sistema implementado para manejar automáticamente múltiples cuentas de Twitter y rotar entre ellas cuando se alcanzan límites de rate limiting de la API. Esto permite continuidad en la recolección de datos sin interrupciones por restricciones de la API.

---

## 🎯 Problema Identificado

### Situación Anterior
- Twitter API tiene límites estrictos de rate limiting (requests por 15 minutos)
- Cuando se alcanzaba el límite, el sistema fallaba completamente
- Era necesario esperar 15 minutos antes de poder hacer nuevos requests
- Downtime prolongado en crawling de datos
- Errores HTTP 429 (Too Many Requests) sin manejo

### Impacto
- ❌ Interrupciones en recolección de datos
- ❌ Jobs de Sidekiq fallando repetidamente
- ❌ Datos incompletos en dashboards
- ❌ Experiencia de usuario degradada

---

## 💡 Solución Implementada

### Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                    Twitter API Requests                      │
│                                                               │
│  GetPostsDataAuth → AccountManager → Active Credentials      │
│        ↓                   ↓                                  │
│   Rate Limit?          Detect Error                          │
│        ↓                   ↓                                  │
│   Mark Limited        Rotate Account                         │
│        ↓                   ↓                                  │
│   15min Cooldown     Retry with Account 2                    │
└─────────────────────────────────────────────────────────────┘
```

### Componentes Principales

#### 1. **TwitterServices::AccountManager**
**Ubicación**: `app/services/twitter_services/account_manager.rb`

Servicio centralizado que gestiona múltiples credenciales de Twitter:

**Funcionalidades:**
- ✅ Carga y valida múltiples cuentas desde ENV variables
- ✅ Detecta errores de rate limiting (HTTP 429, código 88, 326)
- ✅ Rota automáticamente a cuenta disponible
- ✅ Implementa cooldown de 15 minutos por cuenta
- ✅ Usa Rails.cache para persistir estado
- ✅ Logging detallado para monitoreo

**Métodos principales:**
```ruby
# Obtener credenciales de cuenta activa (no rate limited)
credentials = manager.get_active_credentials
# => { auth_token: "...", ct0_token: "...", account_index: 0, name: "Account 1" }

# Marcar cuenta como rate limited (inicia cooldown)
manager.mark_rate_limited(account_index, error_message)

# Verificar si cuenta está limitada
manager.account_rate_limited?(0) # => true/false

# Ver estado de todas las cuentas
manager.accounts_status
# => [{ name: "Account 1", available: false, cooldown_remaining_seconds: 720 }, ...]

# Verificar si un error es de rate limit
TwitterServices::AccountManager.rate_limit_error?("Rate limit exceeded")
# => true
```

**Detección de Rate Limits:**
El sistema detecta los siguientes indicadores:
- `Rate limit` / `rate limit` en mensaje de error
- `Too Many Requests`
- `code: 88` (Twitter API: Rate limit exceeded)
- `code: 326` (Account temporarily locked)
- `code: 429` (HTTP: Too Many Requests)

#### 2. **GetPostsDataAuth (Actualizado)**
**Ubicación**: `app/services/twitter_services/get_posts_data_auth.rb`

Servicio principal de crawling ahora integrado con AccountManager:

**Cambios implementados:**
```ruby
def initialize(user_id, max_requests: 3, use_proxy: false)
  # ... existing code ...
  
  # ✅ NUEVO: Inicializar AccountManager
  @account_manager = TwitterServices::AccountManager.new
  
  # ✅ NUEVO: Obtener credenciales desde manager
  credentials = @account_manager.get_active_credentials
  @auth_token = credentials[:auth_token]
  @ct0_token = credentials[:ct0_token]
  @current_account_index = credentials[:account_index]
end
```

**Lógica de rotación automática:**
```ruby
unless response.success?
  error_message = data['errors']&.map { |err| err['message'] }&.join(', ')
  
  # ✅ NUEVO: Detectar rate limit y rotar
  if TwitterServices::AccountManager.rate_limit_error?(error_message) || response.code == 429
    @account_manager.mark_rate_limited(@current_account_index, error_message)
    
    # Intentar rotar a otra cuenta
    new_credentials = @account_manager.get_active_credentials
    if new_credentials[:account_index] != @current_account_index
      # Actualizar credenciales y reintentar
      @auth_token = new_credentials[:auth_token]
      @ct0_token = new_credentials[:ct0_token]
      @current_account_index = new_credentials[:account_index]
      
      sleep(2)
      retry # ← Reintenta con la nueva cuenta
    end
  end
end
```

---

## 🔧 Configuración

### Variables de Entorno

#### Cuenta Principal (REQUERIDA)
```bash
TWITTER_AUTH_TOKEN="tu_auth_token_de_cookies"
TWITTER_CT0_TOKEN="tu_ct0_token_de_cookies"
```

#### Cuenta Secundaria (RECOMENDADA - para rotación)
```bash
TWITTER_AUTH_TOKEN2="tu_segundo_auth_token"
TWITTER_CT0_TOKEN2="tu_segundo_ct0_token"
```

#### Cuenta Terciaria (OPCIONAL - capacidad adicional)
```bash
TWITTER_AUTH_TOKEN3="tu_tercer_auth_token"
TWITTER_CT0_TOKEN3="tu_tercer_ct0_token"
```

#### Otras Variables
```bash
TWITTER_BEARER_TOKEN="..." # Optional
SCRAPE_DO_TOKEN="..."      # Optional (para proxy)
```

### Cómo Obtener los Tokens

1. **Abrir Twitter/X en navegador**
2. **Iniciar sesión** con la cuenta
3. **Abrir DevTools** (F12 o Cmd+Option+I)
4. **Ir a Application → Cookies → https://twitter.com**
5. **Copiar valores:**
   - `auth_token` → `TWITTER_AUTH_TOKEN`
   - `ct0` → `TWITTER_CT0_TOKEN`

⚠️ **IMPORTANTE**: 
- Los tokens expiran periódicamente
- Usar cuentas diferentes para cada token set
- No compartir tokens públicamente
- Rotar tokens cada 2-4 semanas

---

## 🚀 Uso

### Uso Automático
El sistema funciona **automáticamente** sin cambios en el código existente:

```ruby
# Código existente sigue funcionando igual
result = TwitterServices::GetPostsDataAuth.call('123456789')

# Internamente:
# 1. AccountManager selecciona cuenta disponible
# 2. Si falla por rate limit → marca cuenta limited
# 3. Rota automáticamente a Account 2
# 4. Reintenta request con nueva cuenta
# 5. Todo transparente para el caller
```

### Rake Tasks para Monitoreo

#### 1. Ver Estado de Cuentas
```bash
rake twitter:accounts:status
```

**Output esperado:**
```
================================================================================
TWITTER ACCOUNTS STATUS
================================================================================

Account 1 (Primary) (Index: 0)
  Status: ✅ AVAILABLE
  Ready to use

Account 2 (Secondary) (Index: 1)
  Status: ❌ RATE LIMITED
  Cooldown: 12 minutes remaining (720s)

--------------------------------------------------------------------------------
Summary: 1/2 accounts available
================================================================================
```

#### 2. Verificar Variables de Entorno
```bash
rake twitter:accounts:verify_env
```

**Output esperado:**
```
================================================================================
TWITTER ENVIRONMENT VARIABLES
================================================================================

✅ TWITTER_AUTH_TOKEN      [REQUIRED]   abc123...xyz789
✅ TWITTER_CT0_TOKEN       [REQUIRED]   def456...uvw012
✅ TWITTER_AUTH_TOKEN2     [OPTIONAL]   ghi789...rst345
✅ TWITTER_CT0_TOKEN2      [OPTIONAL]   jkl012...opq678
⚪ TWITTER_BEARER_TOKEN    [OPTIONAL]   
⚪ SCRAPE_DO_TOKEN         [OPTIONAL]   

--------------------------------------------------------------------------------
✅ All required variables are set
✅ Backup account configured (Account 2)
================================================================================
```

#### 3. Test de Rotación
```bash
rake twitter:accounts:test_rotation
```

Simula un rate limit y verifica que la rotación funcione correctamente.

#### 4. Limpiar Cooldowns
```bash
rake twitter:accounts:clear_cooldowns
```

Útil después de renovar tokens o para testing.

---

## 📊 Flujo de Operación

### Escenario 1: Operación Normal
```
1. User solicita crawling de tweets
2. GetPostsDataAuth inicializa
3. AccountManager → selecciona Account 1 (disponible)
4. Request exitoso → procesa tweets
5. ✅ Success
```

### Escenario 2: Rate Limit + Rotación Exitosa
```
1. User solicita crawling de tweets
2. GetPostsDataAuth inicializa
3. AccountManager → selecciona Account 1
4. Request → Twitter API
5. ❌ Response: 429 Too Many Requests
6. AccountManager detecta rate limit
7. AccountManager marca Account 1 como limited (cooldown 15min)
8. AccountManager → selecciona Account 2 (disponible)
9. GetPostsDataAuth actualiza credenciales
10. Retry request con Account 2
11. Request exitoso → procesa tweets
12. ✅ Success (transparente para usuario)
```

### Escenario 3: Todas las Cuentas Rate Limited
```
1. User solicita crawling
2. AccountManager verifica todas las cuentas
3. Account 1: limited (10 min remaining)
4. Account 2: limited (5 min remaining)
5. AccountManager selecciona Account 2 (menos cooldown)
6. Request → Twitter API
7. ❌ Response: 429 (esperado)
8. Job falla pero con mensaje informativo
9. Sidekiq reintentará en 5 minutos (cooldown expirado)
10. ✅ Success en retry automático
```

---

## 🔍 Monitoreo y Debugging

### Logs a Revisar

**Inicialización:**
```
[TwitterAccountManager] Initialized with 2 account(s)
  [0] Account 1 (Primary)
  [1] Account 2 (Secondary)
```

**Selección de Cuenta:**
```
[TwitterAccountManager] Using Account 1 (Primary) (not rate limited)
```

**Detección de Rate Limit:**
```
[TwitterServices::GetPostsDataAuth] Rate limit detected: Rate limit exceeded
[TwitterAccountManager] Account 1 (Primary) marked as RATE LIMITED until 15:45:00. Error: Rate limit exceeded
```

**Rotación Exitosa:**
```
[TwitterAccountManager] Switching to Account 2 (Secondary)
[TwitterServices::GetPostsDataAuth] Rotating to Account 2 (Secondary)
```

**Warning (todas limited):**
```
[TwitterAccountManager] All accounts rate limited. Using Account 2 (Secondary) (cooldown: 300s remaining)
```

### Rails Console para Debugging

```ruby
# Verificar estado de cuentas
manager = TwitterServices::AccountManager.new
manager.accounts_status
# => [{ name: "Account 1", available: true, ... }, ...]

# Ver qué cuenta está activa
credentials = manager.get_active_credentials
puts credentials[:name]
# => "Account 1 (Primary)"

# Simular rate limit (para testing)
manager.mark_rate_limited(0, "Test rate limit")

# Verificar cooldown
manager.get_remaining_cooldown(0)
# => 892 (segundos)

# Limpiar estado (para testing)
Rails.cache.clear

# Ver logs en tiempo real
tail -f log/development.log | grep TwitterAccount
```

---

## 🎯 Beneficios Implementados

### Para Operaciones
✅ **Continuidad de servicio**: Sin downtime por rate limits  
✅ **Automático**: No requiere intervención manual  
✅ **Resiliente**: Maneja múltiples escenarios de falla  
✅ **Transparente**: No requiere cambios en código existente  

### Para Desarrollo
✅ **Centralizado**: Un solo lugar para gestión de credenciales  
✅ **Testeable**: Rake tasks para validación  
✅ **Observable**: Logging detallado  
✅ **Extensible**: Fácil agregar más cuentas  

### Para Monitoreo
✅ **Estado en tiempo real**: Rake tasks  
✅ **Logging estructurado**: Fácil debugging  
✅ **Métricas claras**: Cooldowns, rotaciones  

---

## 📈 Mejoras Futuras (Opcional)

### Fase 2 (Si es necesario)
- [ ] Dashboard web para ver estado de cuentas
- [ ] Métricas en Redis para analytics (requests/cuenta)
- [ ] Notificaciones cuando todas las cuentas están limited
- [ ] Auto-refresh de tokens desde API
- [x] Soporte para 3 cuentas ✅ (implementado)
- [ ] Soporte para 4+ cuentas (si se necesita en el futuro)
- [ ] Rate limit prediction (machine learning)

### Integración con Sidekiq
```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.death_handlers << lambda do |job, ex|
    # Verificar si fue rate limit
    if TwitterServices::AccountManager.rate_limit_error?(ex.message)
      # Esperar cooldown antes de reintentar
      job.retry_in = 15.minutes
    end
  end
end
```

---

## ⚠️ Consideraciones Importantes

### Seguridad
- ⚠️ **NO** commitear tokens al repositorio
- ⚠️ Usar `.env` o variables de entorno del servidor
- ⚠️ Rotar tokens regularmente
- ⚠️ Monitorear intentos de acceso no autorizados

### Límites de Twitter
- **Rate Limits**: 15 minutos por ventana
- **Requests**: ~300 requests por 15 min (varía por endpoint)
- **Cooldown**: Respetar los 15 minutos completos
- **Ban Risk**: Evitar requests agresivos

### Mantenimiento
- Verificar tokens expirados cada 2-4 semanas
- Monitorear logs para patrones anormales
- Documentar cambios en credenciales
- Backup de tokens en almacenamiento seguro

---

## 🧪 Testing

### Test Manual

```bash
# 1. Verificar ENV
rake twitter:accounts:verify_env

# 2. Ver estado inicial
rake twitter:accounts:status

# 3. Test de rotación
rake twitter:accounts:test_rotation

# 4. Limpiar estado
rake twitter:accounts:clear_cooldowns

# 5. Crawl real
rails c
> profile = TwitterProfile.first
> TwitterServices::ProcessPosts.call(profile.uid)

# 6. Revisar logs
tail -f log/development.log | grep -E "Twitter|Rate|Account"
```

### Test de Integración

```ruby
# test/services/twitter_services/account_manager_test.rb
require 'test_helper'

class TwitterServices::AccountManagerTest < ActiveSupport::TestCase
  test "should initialize with valid accounts" do
    manager = TwitterServices::AccountManager.new
    assert_not_nil manager
  end

  test "should detect rate limit errors" do
    assert TwitterServices::AccountManager.rate_limit_error?("Rate limit exceeded")
    assert TwitterServices::AccountManager.rate_limit_error?("code: 88")
    assert TwitterServices::AccountManager.rate_limit_error?("Too Many Requests")
  end

  test "should rotate accounts when rate limited" do
    manager = TwitterServices::AccountManager.new
    
    creds1 = manager.get_active_credentials
    manager.mark_rate_limited(creds1[:account_index], "Test")
    
    creds2 = manager.get_active_credentials
    assert_not_equal creds1[:account_index], creds2[:account_index]
  end
end
```

---

## 📞 Soporte

### Problemas Comunes

**1. "No Twitter accounts configured"**
- **Causa**: Falta TWITTER_AUTH_TOKEN o TWITTER_CT0_TOKEN
- **Solución**: Verificar `.env` o variables de entorno

**2. "All accounts rate limited"**
- **Causa**: Ambas cuentas alcanzaron límite
- **Solución**: Esperar 15 minutos o agregar tercera cuenta

**3. Tokens expirados**
- **Causa**: Twitter invalidó sesión
- **Solución**: Obtener nuevos tokens desde navegador

**4. Jobs fallando constantemente**
- **Causa**: Posible ban temporal de IP/cuenta
- **Solución**: Contactar con Twitter Support, usar proxy

### Contacto
- **Desarrollo**: Ver logs en `log/production.log`
- **Operaciones**: Usar rake tasks para diagnosticar
- **Emergencia**: Limpiar cooldowns y reiniciar Sidekiq

---

## 📚 Referencias

- [Twitter API Rate Limits](https://developer.twitter.com/en/docs/twitter-api/rate-limits)
- [Rails Caching Guide](https://guides.rubyonrails.org/caching_with_rails.html)
- [HTTParty Documentation](https://github.com/jnunemaker/httparty)

---

**Última actualización**: Noviembre 7, 2025  
**Autor**: Bruno Sacco (con AI assistance)  
**Estado**: ✅ Producción Ready


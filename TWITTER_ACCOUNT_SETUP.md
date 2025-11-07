# ⚡ Twitter Account Rotation - Quick Setup Guide

**Sistema de rotación automática de cuentas para evitar rate limits de Twitter API**

---

## 📋 ¿Qué hace esto?

Cuando una cuenta de Twitter alcanza el límite de requests (rate limit), el sistema **automáticamente cambia a otra cuenta** y continúa funcionando sin interrupciones.

**Beneficios:**
- ✅ Sin downtime por rate limits
- ✅ Rotación automática transparente
- ✅ Logs detallados para monitoreo
- ✅ Fácil de configurar

---

## 🚀 Setup Rápido (5 minutos)

### 1️⃣ Agregar Variables de Entorno

Edita tu archivo `.env` y agrega:

```bash
# Cuenta Principal (REQUERIDA)
TWITTER_AUTH_TOKEN="tu_auth_token_aqui"
TWITTER_CT0_TOKEN="tu_ct0_token_aqui"

# Cuenta Secundaria (RECOMENDADA - para rotación automática)
TWITTER_AUTH_TOKEN2="tu_segundo_auth_token"
TWITTER_CT0_TOKEN2="tu_segundo_ct0_token"

# Cuenta Terciaria (OPCIONAL - para capacidad adicional)
TWITTER_AUTH_TOKEN3="tu_tercer_auth_token"
TWITTER_CT0_TOKEN3="tu_tercer_ct0_token"
```

### 2️⃣ Obtener los Tokens

Para cada cuenta de Twitter:

1. Abre Twitter/X en tu navegador
2. Inicia sesión con la cuenta
3. Abre DevTools (F12 o Cmd+Option+I en Mac)
4. Ve a: **Application** → **Cookies** → **https://twitter.com**
5. Busca y copia:
   - `auth_token` → úsalo para `TWITTER_AUTH_TOKEN`
   - `ct0` → úsalo para `TWITTER_CT0_TOKEN`

⚠️ **Importante**: Usa **cuentas diferentes** para Account 1, Account 2 y Account 3.

### 3️⃣ Verificar Configuración

```bash
# Opción 1: Script de verificación
ruby scripts/verify_twitter_accounts.rb

# Opción 2: Rake task
rake twitter:accounts:verify_env
```

✅ Si ves "All checks passed", estás listo!

---

## 🎮 Comandos Útiles

### Ver Estado de Cuentas
```bash
rake twitter:accounts:status
```

Output:
```
Account 1 (Primary) (Index: 0)
  Status: ✅ AVAILABLE
  
Account 2 (Secondary) (Index: 1)
  Status: ❌ RATE LIMITED
  Cooldown: 12 minutes remaining
```

### Verificar ENV Variables
```bash
rake twitter:accounts:verify_env
```

### Test de Rotación
```bash
rake twitter:accounts:test_rotation
```

### Limpiar Cooldowns (después de renovar tokens)
```bash
rake twitter:accounts:clear_cooldowns
```

---

## 🔄 ¿Cómo Funciona?

### Sin Rate Limit (Normal)
```
1. Request → Twitter API con Account 1
2. ✅ Success
3. Continúa usando Account 1
```

### Con Rate Limit (Rotación Automática)
```
1. Request → Twitter API con Account 1
2. ❌ Error: "Rate limit exceeded" (HTTP 429)
3. Sistema detecta rate limit automáticamente
4. Marca Account 1 como "limited" (cooldown 15 minutos)
5. Cambia automáticamente a Account 2
6. Reintenta request con Account 2
7. ✅ Success - sin intervención manual
```

### Cuando Todas las Cuentas están Limited
```
1. Sistema usa la cuenta con menor cooldown restante
2. Si falla, Sidekiq reintentará automáticamente cuando expire cooldown
3. En 15 minutos, al menos una cuenta estará disponible
4. Con 3 cuentas, esto es muy poco probable de ocurrir
```

---

## 📊 Monitoreo

### Ver Logs en Tiempo Real
```bash
tail -f log/development.log | grep -E "Twitter|Rate|Account"
```

### Logs Importantes

**✅ Funcionando Normal:**
```
[TwitterAccountManager] Using Account 1 (Primary) (not rate limited)
```

**⚠️ Rate Limit Detectado:**
```
[TwitterAccountManager] Account 1 marked as RATE LIMITED until 15:45:00
[TwitterAccountManager] Switching to Account 2 (Secondary)
```

**✅ Rotación Exitosa:**
```
[TwitterServices::GetPostsDataAuth] Rotating to Account 2 (Secondary)
[TwitterServices::GetPostsDataAuth] Request succeeded with Account 2
```

---

## 🧪 Testing

### Test Manual Completo
```bash
# 1. Verificar ENV
rake twitter:accounts:verify_env

# 2. Ver estado
rake twitter:accounts:status

# 3. Test rotación
rake twitter:accounts:test_rotation

# 4. Limpiar
rake twitter:accounts:clear_cooldowns

# 5. Test real con API
rails console
> profile = TwitterProfile.first
> result = TwitterServices::ProcessPosts.call(profile.uid)
> puts result.success? ? "✅ Success" : "❌ Error: #{result.error}"
```

---

## ⚠️ Troubleshooting

### "No Twitter accounts configured"
**Problema**: Faltan variables de entorno  
**Solución**: 
```bash
# Verificar que .env tiene:
TWITTER_AUTH_TOKEN="..."
TWITTER_CT0_TOKEN="..."
```

### "All accounts rate limited"
**Problema**: Todas las cuentas alcanzaron el límite  
**Solución**: 
- Esperar 15 minutos para que expire el cooldown
- Si tienes solo 2 cuentas, agregar tercera: `TWITTER_AUTH_TOKEN3` + `TWITTER_CT0_TOKEN3`
- Con 3 cuentas esto es muy raro que ocurra

### Tokens Expirados
**Problema**: Twitter invalidó la sesión  
**Solución**: 
1. Obtener nuevos tokens desde navegador (ver paso 2️⃣)
2. Actualizar `.env`
3. Limpiar cooldowns: `rake twitter:accounts:clear_cooldowns`
4. Reiniciar Sidekiq si está corriendo

### Jobs Fallando Constantemente
**Problema**: Posible ban o bloqueo de IP  
**Solución**:
1. Verificar en Twitter si la cuenta está suspendida
2. Esperar 24 horas
3. Considerar usar proxy (configurar `USE_SCRAPE_DO_PROXY=true`)

---

## 📚 Documentación Completa

Para detalles técnicos, arquitectura y troubleshooting avanzado:
```
docs/implementation/TWITTER_ACCOUNT_ROTATION_SYSTEM.md
```

---

## 🔒 Seguridad

⚠️ **NUNCA** commitear tokens al repositorio  
✅ Usar `.env` (ya está en `.gitignore`)  
✅ Rotar tokens cada 2-4 semanas  
✅ Usar cuentas diferentes para cada set de tokens  
✅ Monitorear logs para accesos sospechosos  

---

## 📞 Ayuda

**Verificación rápida:**
```bash
ruby scripts/verify_twitter_accounts.rb
```

**Ver estado:**
```bash
rake twitter:accounts:status
```

**Logs:**
```bash
tail -f log/production.log | grep TwitterAccount
```

---

## ✅ Checklist de Producción

Antes de deployar:

- [ ] Variables de entorno configuradas (mínimo Account 1)
- [ ] Account 2 configurada (recomendado)
- [ ] Script de verificación pasó: `ruby scripts/verify_twitter_accounts.rb`
- [ ] Test manual exitoso en consola de Rails
- [ ] Monitoreo configurado (logs)
- [ ] Tokens documentados en lugar seguro (password manager)
- [ ] Configurado alarm/alert cuando todas las cuentas están limited (opcional)

---

**Última actualización**: Noviembre 7, 2025  
**Versión**: 1.0  
**Estado**: ✅ Producción Ready


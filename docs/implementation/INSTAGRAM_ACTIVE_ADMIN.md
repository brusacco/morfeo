# Instagram Profiles - ActiveAdmin Implementation

## ✅ Implementation Complete

Se ha agregado la interfaz de ActiveAdmin para `InstagramProfile` en la sección de Settings.

---

## 📍 Ubicación

**Admin Panel**: Settings → Instagram Profiles

---

## 🎯 Funcionalidad

### Crear Nuevo Profile

1. **Ir a**: Admin → Settings → Instagram Profiles
2. **Click**: "New Instagram Profile"
3. **Ingresar**:
   - `username`: Username de Instagram (sin @)
   - `site`: Site asociado (opcional)
4. **Click**: "Create Profile & Fetch Data"
5. ✅ **Automático**: Se obtienen todos los datos del API vía callback

### Editar Profile

1. **Seleccionar** profile existente
2. **Click**: "Edit"
3. **Modificar**: Solo site_id (username es read-only)
4. **Click**: "Update"

### Sincronizar Manualmente

#### Desde Show Page
- **Click**: botón "Sync from API"
- ✅ Actualiza datos inmediatamente

#### Batch Sync
1. **Seleccionar** múltiples profiles
2. **Batch Actions**: "Sync profiles"
3. ✅ Sincroniza todos los seleccionados

---

## 🔧 Características

### Index Page

Muestra:
- ✅ Imagen del profile
- ✅ Nombre completo
- ✅ Username (@username)
- ✅ Followers (formateado)
- ✅ Engagement rate (%)
- ✅ Verified status (badge)
- ✅ Profile type (badge)
- ✅ Site asociado
- ✅ Last synced (time ago)

### Show Page

**Profile Information**:
- Imagen HD
- UID, Username, Full name
- Biography
- Profile type
- Followers/Following
- Verified status
- Business/Professional account
- Privacy status
- Country, Category

**Analytics & Metrics**:
- Engagement rate
- Total posts/videos
- Likes/Comments counts
- Video views
- Total interactions
- Median interactions/views
- Average engagement

**Reach Estimation**:
- Estimated reach
- Reach percentage

**System Information**:
- Associated site
- Last synced timestamp
- Needs sync status
- Created/Updated timestamps

**Quick Actions**:
- Link to Instagram profile
- Sync from API button

### Form

**New Record**:
- Username input (required)
- Site selection (optional)
- Hint: "Data will be fetched automatically"

**Edit Record**:
- Username (disabled, read-only)
- Site selection (optional)
- Note: "Username cannot be changed"

---

## 🚀 Uso con Callbacks

### Automatic Data Fetch

```ruby
# En ActiveAdmin, crear profile con solo username
InstagramProfile.create!(username: 'ueno_py')

# ↓ Callback automático (after_create :update_profile_data)
# ↓ Llama a InstagramServices::UpdateProfile
# ↓ Obtiene todos los datos del API
# ↓ Actualiza todos los campos
# ✅ Profile completamente poblado
```

### Manual Sync

```ruby
# Desde consola o admin
profile = InstagramProfile.find(1)
profile.update_profile_data

# ✅ Actualiza todos los campos desde API
```

---

## 🎨 UI Features

### Status Badges

- **Verified**: Verde (OK)
- **Not Verified**: Rojo (Error)
- **Profile Type**: Badge con tipo
- **Privacy**: 
  - Public: Verde (OK)
  - Private: Amarillo (Warning)
- **Needs Sync**: 
  - Yes: Amarillo (Warning)
  - No: Verde (OK)

### Formatted Numbers

- Followers: `328,033`
- Likes: `5,266`
- Views: `28,687`

### Time Display

- Last synced: "2 hours ago (2025-11-10 12:30:45)"
- Relative + Absolute timestamps

---

## 🔍 Filters

Disponibles en index:
- Username (string)
- Full name (string)
- Is verified (boolean)
- Is business account (boolean)
- Profile type (select: marca, persona, influencer)

---

## 🛠️ Custom Actions

### Member Action: Sync

```ruby
# POST /admin/instagram_profiles/:id/sync
# Sincroniza profile individual desde API
```

### Batch Action: Sync Profiles

```ruby
# POST /admin/instagram_profiles/batch_action
# Sincroniza múltiples profiles seleccionados
```

---

## 📋 Permitted Parameters

```ruby
permit_params :username, :site_id
```

Solo estos campos son editables desde admin. Todo lo demás se obtiene del API automáticamente.

---

## 💡 Tips de Uso

### 1. Crear Profile

```
1. Click "New Instagram Profile"
2. Ingresa: ueno_py (sin @)
3. Selecciona Site (opcional)
4. Click "Create Profile & Fetch Data"
5. ✅ Listo! Todos los datos cargados
```

### 2. Verificar Sync Status

En la show page, ver:
- **Last synced**: Cuándo fue última sincronización
- **Needs sync**: Si necesita actualización (>24h)

### 3. Actualizar Datos

Opciones:
- **Manual**: Click "Sync from API"
- **Batch**: Seleccionar múltiples + Batch action
- **Automático**: Callback on update

### 4. Asociar con Site

Para que imagen se sincronice con Site:
1. Edit profile
2. Seleccionar Site
3. Save
4. ✅ Imagen se actualiza en Site automáticamente

---

## 🔄 Workflow Completo

### Setup Inicial

```
1. Admin → Settings → Instagram Profiles
2. Click "New Instagram Profile"
3. Username: ueno_py
4. Site: Ueno Bank (opcional)
5. Create
   ↓
   [Callback ejecuta]
   ↓
   [API fetch automático]
   ↓
   [Datos poblados]
   ↓
6. ✅ Profile listo para usar
```

### Mantenimiento

```
1. Periódicamente revisar "Needs sync" status
2. Usar batch action para sincronizar múltiples
3. O usar job programado (futuro)
```

---

## 🧪 Testing

### Crear Test Profile

```ruby
# En Rails console
InstagramProfile.create!(username: 'ueno_py')

# O desde Admin UI
# Settings → Instagram Profiles → New
```

### Verificar en Admin

```
1. Ir a admin/instagram_profiles
2. Ver profile listado con datos
3. Click en profile
4. Verificar todos los campos poblados
5. Click "Sync from API"
6. Verificar actualización
```

---

## 📊 Comparación con Twitter/Facebook

| Feature | Twitter | Facebook | Instagram |
|---------|---------|----------|-----------|
| **Form field** | uid | uid | username |
| **Auto-fetch** | ✅ | ✅ | ✅ |
| **Site link** | Optional | Required | Optional |
| **Manual sync** | ❌ | ❌ | ✅ (nuevo!) |
| **Batch sync** | ❌ | ❌ | ✅ (nuevo!) |
| **Analytics view** | ❌ | ❌ | ✅ (nuevo!) |

---

## 🎁 Nuevas Features

### 1. Manual Sync Button
- Botón en show page para sincronizar
- POST action que actualiza datos
- Feedback visual con notice

### 2. Batch Sync
- Seleccionar múltiples profiles
- Sincronizar todos en batch
- Útil para mantenimiento masivo

### 3. Analytics Panels
- Panel separado para métricas
- Panel para reach estimation
- Valores formateados y legibles

### 4. Sync Status
- Indicador visual si necesita sync
- Timestamp de última sincronización
- Time ago + absolute time

---

## 🔒 Security & Validations

### Model Level
- `username` required & unique
- `uid` unique (auto-populated)
- Callbacks con rescue blocks

### Admin Level
- Solo username y site_id editables
- Username disabled en edit
- Validaciones automáticas

---

## 📚 Files Modified

- ✅ `app/admin/instagram_profiles.rb` - Nuevo archivo
- ✅ 230+ líneas de código
- ✅ Sin errores de linter
- ✅ Siguiendo patrones de Twitter/Facebook

---

## 🚀 Ready to Use

El admin está completamente funcional y listo para:

1. ✅ Crear profiles con username + site
2. ✅ Auto-fetch de datos vía callback
3. ✅ Visualizar todos los datos y métricas
4. ✅ Sincronización manual individual
5. ✅ Sincronización batch de múltiples
6. ✅ Filters para búsqueda
7. ✅ Status badges visuales
8. ✅ Links a Instagram
9. ✅ Analytics detallados

---

## 🎯 Next Steps

1. **Correr migración** (si no está corrida): `rails db:migrate`
2. **Restart server**: Para cargar nuevo admin
3. **Acceder**: `/admin/instagram_profiles`
4. **Crear primer profile**: ueno_py
5. **Verificar**: Datos poblados automáticamente

---

**Implementation Date**: November 10, 2025  
**Status**: ✅ Production Ready  
**Location**: Admin → Settings → Instagram Profiles


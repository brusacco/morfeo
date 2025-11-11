# 🛡️ Cloudflare Bypass Improvements

## Problema Encontrado

Algunos sitios (como **Ñanduti**) están protegidos por Cloudflare y detectan el crawler como un bot, mostrando solo una página de verificación en lugar del contenido real.

```
⚠️ WARNING: Found links but NONE matched the filter!
   Filter: ^https:\/\/nanduti.com.py\/\S+\S+
   
   Sample links found (first 5):
     - https://www.cloudflare.com/?utm_source=challenge&utm_campaign=m
```

## Mejoras Implementadas ✅

### 1. **Nuevo Modo Headless (Menos Detectable)**
```ruby
options.add_argument('--headless=new')  # En lugar de '--headless'
```
El nuevo modo headless es más difícil de detectar para sistemas anti-bot.

### 2. **Remover Flags de Automatización**
```ruby
options.add_argument('--disable-blink-features=AutomationControlled')
options.add_preference('excludeSwitches', ['enable-automation'])
options.add_preference('useAutomationExtension', false)
```
Esto elimina señales obvias de que es un navegador automatizado.

### 3. **JavaScript Anti-Detección**
```ruby
@driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
```
Elimina la propiedad `navigator.webdriver` que Cloudflare verifica.

### 4. **Detección y Espera de Cloudflare**
```ruby
def cloudflare_detected?(driver)
  page_source = driver.page_source
  page_source.include?('Checking your browser') || 
  page_source.include?('cloudflare') ||
  page_source.include?('cf-browser-verification')
end

def wait_for_cloudflare_clearance(driver, max_wait: 10)
  # Espera hasta 10 segundos para que Cloudflare termine
  max_wait.times do
    sleep(1)
    return true unless cloudflare_detected?(driver)
  end
end
```
Si detecta un challenge de Cloudflare, espera automáticamente hasta 10 segundos.

### 5. **Tamaño de Ventana Realista**
```ruby
options.add_argument('--window-size=1920,1080')
```
Usa una resolución común de escritorio.

## Cómo Probar

```bash
# Probar solo Ñanduti (el sitio problemático)
rake crawler:headless:site[134]

# Probar todos los sitios
rake crawler:headless
```

## Resultados Esperados

**Antes:**
```
🔗 Found 0 article link(s)
Sample links: https://www.cloudflare.com/?utm_source=challenge...
```

**Después:**
```
🔗 Found 15 article link(s)
   [1/15] https://nanduti.com.py/noticia/... ○
   [2/15] https://nanduti.com.py/noticia/... ✓
```

## Limitaciones

Estas mejoras funcionan para la mayoría de protecciones básicas de Cloudflare, pero:

1. **Cloudflare "Under Attack Mode"**: Si el sitio tiene protección extrema, puede seguir bloqueando
2. **CAPTCHA Interactivo**: Si Cloudflare muestra un CAPTCHA manual, no se puede resolver automáticamente
3. **Rate Limiting**: Si haces muchas requests muy rápido, pueden seguir bloqueando

## Soluciones Alternativas (Si Esto No Funciona)

### Opción 1: Deshabilitar Headless (Temporalmente)
```ruby
# En browser_manager.rb, comenta esta línea:
# options.add_argument('--headless=new')
```
**Nota**: Esto abrirá ventanas de Chrome visibles (no recomendado en servidor).

### Opción 2: Usar Proxy Rotativo
Contactar a los administradores de Ñanduti para:
- Agregar tu IP del servidor a una whitelist
- Obtener un API key especial
- Usar un servicio de proxy rotativo

### Opción 3: undetected-chromedriver (Avanzado)
Instalar gem adicional:
```bash
gem install undetected-chromedriver
```
Esta gem hace el browser casi imposible de detectar, pero requiere más configuración.

## Monitoreo

Para ver si Cloudflare está bloqueando:

```bash
# Revisar logs
tail -f log/production.log | grep -i cloudflare

# Buscar warnings específicos
grep "Cloudflare challenge detected" log/production.log
```

Si ves muchos "Cloudflare challenge detected", significa que el sitio tiene protección activa.

## Estado

✅ **Implementado y listo para probar**

Las mejoras están activas para todos los sitios. El crawler ahora:
- Es más difícil de detectar
- Espera automáticamente si Cloudflare muestra un challenge
- Usa técnicas anti-detección estándar

---

**Última actualización**: Noviembre 11, 2025  
**Afecta a**: Ñanduti principalmente, pero mejora todos los sitios  
**Nivel de protección**: Básico-Intermedio (suficiente para la mayoría de casos)


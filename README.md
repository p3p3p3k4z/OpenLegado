# 🇲🇽 Legado - Experiencias Culturales Mexicanas

Una aplicación Flutter moderna que combina la rica herencia cultural mexicana con un diseño contemporáneo y experiencia de usuario intuitiva.

### Notas sobre la actualizacion
- Desmenuzado de codigo
- Mejora en Sistema de tickets
- Panel de Admin y roles
- Mejora en el panel de administracion 
- Mejora en el profile
- Integracion de bd en users,experiencies,bookings,review
- Integracion de reviews en experiencia

### Cambios futuros
- Sistema crud de users (Ya lo habia hecho pero lo rompi D:)
- DISEÑO (Aun no terminamos de decidirnos)
- Implemetacion de temas

### IMPORTANTE
- Actualmente la bd de firebase no se puede actualizar por tema de documentacion,
por lo cual se dejan estan reglas que deberan de ser aplicadas en un futuro

bash```
rules_version = '2';
service firebase.storage {
match /b/{bucket}/o {
// Cualquier usuario autenticado puede leer cualquier archivo.
// Esto es necesario para que las fotos de perfil sean públicas.
match /{allPaths=**} {
allow read: if request.auth != null;
}

    // Reglas específicas para la carpeta de imágenes de perfil.
    match /profile_images/{userId}/{fileName} {
      // Un usuario solo puede CREAR un archivo en su propia carpeta (userId).
      // 'request.resource.size' se usa para limitar el tamaño del archivo.
      allow create: if request.auth != null && request.auth.uid == userId
                    && request.resource.size < 5 * 1024 * 1024 // Limite de 5MB
                    && request.resource.contentType.matches('image/.*');
      
      // Permitir borrar archivos si eres el dueño.
      allow delete: if request.auth != null && request.auth.uid == userId;
      
      // Permitir a todos los usuarios leer las imágenes.
      allow read;
    }
}
}
```
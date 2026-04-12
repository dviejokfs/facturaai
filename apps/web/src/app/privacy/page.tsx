import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Politica de Privacidad - InvoScanAI",
  description: "Politica de privacidad de InvoScanAI, la app de gestion de facturas para autonomos.",
};

export default function PrivacyPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-16 sm:px-6 sm:py-24">
      <h1 className="font-heading text-3xl font-bold tracking-tight sm:text-4xl">
        Politica de Privacidad
      </h1>
      <p className="mt-4 text-sm text-muted-foreground">
        Ultima actualizacion: 9 de abril de 2026
      </p>

      <div className="prose prose-neutral mt-10 max-w-none text-foreground [&_h2]:font-heading [&_h2]:text-xl [&_h2]:font-semibold [&_h2]:mt-10 [&_h2]:mb-4 [&_h3]:font-heading [&_h3]:text-lg [&_h3]:font-semibold [&_h3]:mt-8 [&_h3]:mb-3 [&_p]:text-muted-foreground [&_p]:leading-relaxed [&_p]:mb-4 [&_ul]:text-muted-foreground [&_ul]:mb-4 [&_ul]:list-disc [&_ul]:pl-6 [&_ul]:space-y-2 [&_li]:leading-relaxed">
        <h2>1. Responsable del Tratamiento</h2>
        <p>
          <strong>Kung Fu Software SL</strong> (en adelante, &ldquo;la Empresa&rdquo;) es responsable del tratamiento
          de los datos personales recogidos a traves de la aplicacion movil InvoScanAI (en adelante, &ldquo;la App&rdquo;)
          y del sitio web asociado.
        </p>
        <p>Correo de contacto: <a href="mailto:info@kungfusoftware.es" className="text-primary hover:underline">info@kungfusoftware.es</a></p>

        <h2>2. Datos que Recopilamos</h2>
        <h3>2.1 Datos de cuenta</h3>
        <ul>
          <li>Nombre y direccion de correo electronico (obtenidos a traves de Apple Sign-In o Google OAuth)</li>
          <li>Identificador unico de usuario</li>
        </ul>

        <h3>2.2 Datos de facturas</h3>
        <ul>
          <li>Fotografias de facturas capturadas con la camara del dispositivo</li>
          <li>Datos extraidos por IA: importes, fechas, nombre del proveedor/cliente, NIF/CIF, conceptos, tipo impositivo</li>
          <li>Clasificacion (gasto/ingreso) y categoria fiscal</li>
        </ul>

        <h3>2.3 Datos tecnicos</h3>
        <ul>
          <li>Tipo de dispositivo, version del sistema operativo</li>
          <li>Token de notificaciones push (APNs)</li>
          <li>Datos de suscripcion gestionados a traves de RevenueCat</li>
        </ul>

        <h3>2.4 Datos de Gmail (opcional)</h3>
        <ul>
          <li>Si el usuario activa la sincronizacion con Gmail, accedemos unicamente a los correos electr&oacute;nicos que contengan facturas adjuntas, con el fin exclusivo de importarlas a la App.</li>
        </ul>

        <h2>3. Finalidad del Tratamiento</h2>
        <p>Utilizamos los datos personales para:</p>
        <ul>
          <li>Prestar el servicio de digitalizacion y gestion de facturas</li>
          <li>Extraer datos de facturas mediante inteligencia artificial</li>
          <li>Clasificar automaticamente las facturas como gasto o ingreso</li>
          <li>Generar exportaciones (CSV, XLSX, ZIP) para facilitar la gestion contable</li>
          <li>Gestionar la suscripcion y los pagos a traves de Apple In-App Purchase</li>
          <li>Enviar notificaciones push relevantes sobre el servicio</li>
        </ul>

        <h2>4. Base Legal</h2>
        <p>
          El tratamiento de datos se basa en la ejecucion del contrato de servicio (art. 6.1.b RGPD)
          y, en su caso, el consentimiento del usuario (art. 6.1.a RGPD) para funcionalidades opcionales
          como la sincronizacion con Gmail.
        </p>

        <h2>5. Almacenamiento y Seguridad</h2>
        <ul>
          <li><strong>Imagenes de facturas:</strong> almacenadas en Amazon Web Services (AWS) S3 con cifrado en reposo (AES-256).</li>
          <li><strong>Datos de usuario y registros de facturas:</strong> almacenados en una base de datos PostgreSQL con acceso restringido y conexiones cifradas (TLS).</li>
          <li><strong>Suscripciones:</strong> gestionadas por RevenueCat; no almacenamos datos de tarjetas de credito.</li>
        </ul>
        <p>
          Aplicamos medidas tecnicas y organizativas adecuadas para proteger los datos personales
          contra el acceso no autorizado, la perdida o la destruccion.
        </p>

        <h2>6. Cesion de Datos a Terceros</h2>
        <p>
          <strong>No vendemos datos personales a terceros.</strong> Los datos solo se comparten con:
        </p>
        <ul>
          <li><strong>Anthropic (Claude API):</strong> las imagenes y PDFs de facturas se envian a la API de Anthropic para su procesamiento mediante inteligencia artificial (extraccion de importes, fechas, proveedor, etc.). Anthropic no utiliza estos datos para entrenar sus modelos. Consulte la <a href="https://www.anthropic.com/legal/privacy" target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">politica de privacidad de Anthropic</a>.</li>
          <li><strong>Amazon Web Services (AWS):</strong> como proveedor de infraestructura (alojamiento de imagenes y bases de datos).</li>
          <li><strong>RevenueCat:</strong> para la gestion de suscripciones.</li>
          <li><strong>Apple:</strong> para la autenticacion (Apple Sign-In) y los pagos (In-App Purchase).</li>
          <li><strong>Google:</strong> para la autenticacion (Google OAuth) y, opcionalmente, la sincronizacion de Gmail.</li>
        </ul>
        <p>
          Todos los proveedores cuentan con acuerdos de tratamiento de datos conformes al RGPD.
        </p>

        <h2>7. Transferencias Internacionales</h2>
        <p>
          Algunos de nuestros proveedores de servicios operan fuera del Espacio Economico Europeo (EEE).
          En estos casos, nos aseguramos de que existan garantias adecuadas (como clausulas contractuales
          tipo aprobadas por la Comision Europea) para proteger sus datos.
        </p>

        <h2>8. Derechos del Usuario (RGPD)</h2>
        <p>De acuerdo con el Reglamento General de Proteccion de Datos, usted tiene derecho a:</p>
        <ul>
          <li><strong>Acceso:</strong> solicitar una copia de sus datos personales.</li>
          <li><strong>Rectificacion:</strong> corregir datos inexactos.</li>
          <li><strong>Supresion:</strong> solicitar la eliminacion de sus datos (&ldquo;derecho al olvido&rdquo;).</li>
          <li><strong>Portabilidad:</strong> recibir sus datos en un formato estructurado y de uso comun.</li>
          <li><strong>Oposicion:</strong> oponerse al tratamiento en determinadas circunstancias.</li>
          <li><strong>Limitacion:</strong> solicitar la limitacion del tratamiento.</li>
        </ul>
        <p>
          Para ejercer estos derechos, contacte con nosotros en{" "}
          <a href="mailto:info@kungfusoftware.es" className="text-primary hover:underline">info@kungfusoftware.es</a>.
          Responderemos en un plazo maximo de 30 dias.
        </p>

        <h2>9. Eliminacion de Cuenta</h2>
        <p>
          Puede eliminar su cuenta directamente desde la App, en la seccion de Ajustes. Al eliminar
          su cuenta, se borraran permanentemente todos sus datos personales, facturas e imagenes
          asociadas en un plazo maximo de 30 dias.
        </p>

        <h2>10. Conservacion de Datos</h2>
        <p>
          Conservamos los datos personales mientras la cuenta del usuario este activa. Tras la
          eliminacion de la cuenta, los datos se borran de forma permanente en un plazo de 30 dias,
          salvo obligacion legal de conservacion (por ejemplo, obligaciones fiscales).
        </p>

        <h2>11. Menores de Edad</h2>
        <p>
          La App no esta dirigida a menores de 16 anos. No recopilamos deliberadamente datos de
          menores de edad. Si detectamos que un menor ha proporcionado datos personales, los
          eliminaremos de inmediato.
        </p>

        <h2>12. Cookies y Tecnologias Similares</h2>
        <p>
          El sitio web puede utilizar cookies esenciales para su funcionamiento. No utilizamos
          cookies de seguimiento o publicidad.
        </p>

        <h2>13. Modificaciones</h2>
        <p>
          Nos reservamos el derecho de modificar esta politica de privacidad. Cualquier cambio
          sera notificado a traves de la App o del sitio web. La fecha de ultima actualizacion
          se indica al inicio de este documento.
        </p>

        <h2>14. Autoridad de Control</h2>
        <p>
          Si considera que el tratamiento de sus datos no es adecuado, puede presentar una
          reclamacion ante la Agencia Espanola de Proteccion de Datos (AEPD):{" "}
          <a href="https://www.aepd.es" target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">www.aepd.es</a>.
        </p>

        <h2>15. Contacto</h2>
        <p>
          Para cualquier consulta relacionada con la privacidad, puede contactarnos en:
        </p>
        <ul>
          <li><strong>Empresa:</strong> Kung Fu Software SL</li>
          <li><strong>Email:</strong> <a href="mailto:info@kungfusoftware.es" className="text-primary hover:underline">info@kungfusoftware.es</a></li>
        </ul>
      </div>
    </div>
  );
}

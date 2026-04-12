import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terminos de Servicio - InvoScanAI",
  description: "Terminos y condiciones de uso de InvoScanAI.",
};

export default function TermsPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-16 sm:px-6 sm:py-24">
      <h1 className="font-heading text-3xl font-bold tracking-tight sm:text-4xl">
        Terminos de Servicio
      </h1>
      <p className="mt-4 text-sm text-muted-foreground">
        Ultima actualizacion: 9 de abril de 2026
      </p>

      <div className="prose prose-neutral mt-10 max-w-none text-foreground [&_h2]:font-heading [&_h2]:text-xl [&_h2]:font-semibold [&_h2]:mt-10 [&_h2]:mb-4 [&_h3]:font-heading [&_h3]:text-lg [&_h3]:font-semibold [&_h3]:mt-8 [&_h3]:mb-3 [&_p]:text-muted-foreground [&_p]:leading-relaxed [&_p]:mb-4 [&_ul]:text-muted-foreground [&_ul]:mb-4 [&_ul]:list-disc [&_ul]:pl-6 [&_ul]:space-y-2 [&_li]:leading-relaxed [&_ol]:text-muted-foreground [&_ol]:mb-4 [&_ol]:list-decimal [&_ol]:pl-6 [&_ol]:space-y-2">
        <h2>1. Identificacion del Prestador</h2>
        <p>
          Estos Terminos de Servicio (en adelante, &ldquo;Terminos&rdquo;) regulan el uso de la aplicacion movil
          InvoScanAI (en adelante, &ldquo;la App&rdquo;) y los servicios asociados, prestados por:
        </p>
        <ul>
          <li><strong>Razon social:</strong> Kung Fu Software SL</li>
          <li><strong>Correo de contacto:</strong> <a href="mailto:info@kungfusoftware.es" className="text-primary hover:underline">info@kungfusoftware.es</a></li>
        </ul>

        <h2>2. Descripcion del Servicio</h2>
        <p>
          InvoScanAI es una aplicacion de gestion de facturas que utiliza inteligencia artificial para:
        </p>
        <ul>
          <li>Escanear y digitalizar facturas a traves de la camara del dispositivo</li>
          <li>Extraer automaticamente datos clave (importes, fechas, NIF, conceptos)</li>
          <li>Clasificar facturas como gastos o ingresos</li>
          <li>Permitir la exportacion de datos en formatos CSV, XLSX y ZIP</li>
          <li>Sincronizar facturas recibidas por correo electronico (Gmail)</li>
        </ul>

        <h2>3. Aceptacion de los Terminos</h2>
        <p>
          Al descargar, instalar o utilizar la App, el usuario acepta estos Terminos en su totalidad.
          Si no esta de acuerdo con alguno de los Terminos, no debera utilizar la App.
        </p>

        <h2>4. Registro y Cuenta de Usuario</h2>
        <p>
          Para utilizar la App es necesario crear una cuenta mediante Apple Sign-In o Google OAuth.
          El usuario es responsable de mantener la confidencialidad de su cuenta y de todas las
          actividades que se realicen bajo la misma.
        </p>

        <h2>5. Planes y Suscripciones</h2>
        <h3>5.1 Plan Gratuito</h3>
        <ul>
          <li>Hasta 5 escaneos de facturas al mes</li>
          <li>Clasificacion automatica con IA</li>
          <li>Exportacion en formato CSV</li>
        </ul>

        <h3>5.2 Plan Pro</h3>
        <ul>
          <li>Escaneos ilimitados</li>
          <li>Exportacion en CSV, XLSX y ZIP</li>
          <li>Sincronizacion con Gmail</li>
          <li>Soporte prioritario</li>
        </ul>
        <p>
          La suscripcion al Plan Pro se gestiona a traves de Apple In-App Purchase. El precio
          y las condiciones de renovacion se muestran en la App Store antes de la compra.
        </p>
        <h3>5.3 Renovacion Automatica</h3>
        <ul>
          <li>El pago se cargara en la cuenta de Apple ID del usuario en el momento de la confirmacion de la compra.</li>
          <li>La suscripcion se renueva automaticamente por el mismo periodo salvo que se cancele al menos 24 horas antes del final del periodo en curso.</li>
          <li>La cuenta sera cargada por la renovacion dentro de las 24 horas previas al final del periodo en curso, al precio de la suscripcion seleccionada.</li>
          <li>El usuario puede gestionar y cancelar la suscripcion desde los ajustes de su cuenta de Apple (Ajustes &rsaquo; [nombre] &rsaquo; Suscripciones) tras la compra.</li>
          <li>No se ofrecen reembolsos por periodos ya iniciados; las politicas de reembolso de Apple son las aplicables.</li>
        </ul>

        <h2>6. Obligaciones del Usuario</h2>
        <p>El usuario se compromete a:</p>
        <ul>
          <li>Proporcionar datos veraces y actualizados</li>
          <li>Utilizar la App unicamente para gestionar facturas legitimas y legales</li>
          <li>No utilizar la App para fines fraudulentos o ilegales</li>
          <li>No intentar acceder a datos de otros usuarios o a los sistemas de la Empresa de forma no autorizada</li>
          <li>Cumplir con la legislacion fiscal aplicable; la App es una herramienta de gestion, no un asesor fiscal</li>
        </ul>

        <h2>7. Propiedad de los Datos</h2>
        <p>
          El usuario conserva la propiedad de todos los datos y facturas que suba a la App.
          La Empresa no reclama ningun derecho de propiedad sobre el contenido del usuario.
          Al utilizar el servicio, el usuario otorga a la Empresa una licencia limitada para
          procesar los datos con el unico fin de prestar el servicio.
        </p>

        <h2>8. Precision de la IA</h2>
        <p>
          La extraccion de datos mediante IA es automatica y puede contener errores. El usuario
          es responsable de verificar la exactitud de los datos extraidos antes de utilizarlos
          para fines contables o fiscales. La Empresa no se responsabiliza de errores derivados
          de la extraccion automatica de datos.
        </p>

        <h2>9. Disponibilidad del Servicio</h2>
        <p>
          La Empresa se esfuerza por mantener la App disponible de forma continua, pero no
          garantiza un tiempo de actividad del 100%. El servicio puede verse interrumpido
          por mantenimiento, actualizaciones o causas de fuerza mayor. La Empresa no sera
          responsable de perdidas derivadas de la indisponibilidad temporal del servicio.
        </p>

        <h2>10. Limitacion de Responsabilidad</h2>
        <p>
          En la medida maxima permitida por la ley, la Empresa no sera responsable de:
        </p>
        <ul>
          <li>Danos indirectos, incidentales o consecuentes derivados del uso de la App</li>
          <li>Perdida de datos causada por el usuario o por circunstancias fuera del control de la Empresa</li>
          <li>Decisiones fiscales o contables tomadas en base a los datos proporcionados por la App</li>
        </ul>

        <h2>11. Propiedad Intelectual</h2>
        <p>
          La App, su diseno, codigo fuente, marcas y contenido son propiedad de Kung Fu Software SL
          y estan protegidos por las leyes de propiedad intelectual e industrial. El usuario no
          adquiere ningun derecho sobre la propiedad intelectual de la Empresa por el uso de la App.
        </p>

        <h2>12. Terminacion y Eliminacion de Cuenta</h2>
        <p>
          El usuario puede eliminar su cuenta en cualquier momento desde la seccion de Ajustes
          de la App. Tras la eliminacion:
        </p>
        <ul>
          <li>Se cancelara cualquier suscripcion activa (el usuario debera cancelar la suscripcion
            tambien desde Apple para evitar cargos futuros)</li>
          <li>Todos los datos personales y facturas se eliminaran en un plazo maximo de 30 dias</li>
        </ul>
        <p>
          La Empresa se reserva el derecho de suspender o cancelar cuentas que incumplan estos
          Terminos, previa notificacion al usuario.
        </p>

        <h2>13. Modificaciones de los Terminos</h2>
        <p>
          La Empresa se reserva el derecho de modificar estos Terminos en cualquier momento.
          Los cambios seran notificados a traves de la App o por correo electronico. El uso
          continuado de la App tras la notificacion de cambios implica la aceptacion de los
          nuevos Terminos.
        </p>

        <h2>14. Ley Aplicable y Jurisdiccion</h2>
        <p>
          Estos Terminos se rigen por la legislacion espanola. Para la resolucion de cualquier
          controversia derivada de estos Terminos, las partes se someten a los juzgados y
          tribunales de la ciudad del domicilio social de la Empresa, salvo que la legislacion
          aplicable al consumidor establezca un fuero diferente.
        </p>

        <h2>15. Contacto</h2>
        <p>
          Para cualquier consulta relacionada con estos Terminos, puede contactarnos en:
        </p>
        <ul>
          <li><strong>Empresa:</strong> Kung Fu Software SL</li>
          <li><strong>Email:</strong> <a href="mailto:info@kungfusoftware.es" className="text-primary hover:underline">info@kungfusoftware.es</a></li>
        </ul>
      </div>
    </div>
  );
}

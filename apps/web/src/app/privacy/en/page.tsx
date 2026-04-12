import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy - InvoScanAI",
  description: "Privacy policy for InvoScanAI, the invoice management app for freelancers.",
};

export default function PrivacyPageEN() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-16 sm:px-6 sm:py-24">
      <h1 className="font-heading text-3xl font-bold tracking-tight sm:text-4xl">
        Privacy Policy
      </h1>
      <p className="mt-4 text-sm text-muted-foreground">
        Last updated: April 9, 2026
      </p>

      <div className="prose prose-neutral mt-10 max-w-none text-foreground [&_h2]:font-heading [&_h2]:text-xl [&_h2]:font-semibold [&_h2]:mt-10 [&_h2]:mb-4 [&_h3]:font-heading [&_h3]:text-lg [&_h3]:font-semibold [&_h3]:mt-8 [&_h3]:mb-3 [&_p]:text-muted-foreground [&_p]:leading-relaxed [&_p]:mb-4 [&_ul]:text-muted-foreground [&_ul]:mb-4 [&_ul]:list-disc [&_ul]:pl-6 [&_ul]:space-y-2 [&_li]:leading-relaxed">
        <h2>1. Data Controller</h2>
        <p>
          <strong>Kung Fu Software SL</strong> (&ldquo;the Company&rdquo;) is the data controller
          for personal data collected through the InvoScanAI mobile application (&ldquo;the App&rdquo;)
          and associated website.
        </p>
        <p>Contact email: <a href="mailto:info@kungfusoftware.es" className="text-primary hover:underline">info@kungfusoftware.es</a></p>

        <h2>2. Data We Collect</h2>
        <h3>2.1 Account data</h3>
        <ul>
          <li>Name and email address (obtained via Apple Sign-In or Google OAuth)</li>
          <li>Unique user identifier</li>
        </ul>

        <h3>2.2 Invoice data</h3>
        <ul>
          <li>Invoice photos captured with the device camera</li>
          <li>Data extracted by AI: amounts, dates, vendor/client name, tax ID, line items, tax rate</li>
          <li>Classification (expense/income) and tax category</li>
        </ul>

        <h3>2.3 Technical data</h3>
        <ul>
          <li>Device type, operating system version</li>
          <li>Push notification token (APNs)</li>
          <li>Subscription data managed via RevenueCat</li>
        </ul>

        <h3>2.4 Gmail data (optional)</h3>
        <ul>
          <li>If the user enables Gmail sync, we access only emails containing invoice attachments, solely to import them into the App.</li>
        </ul>

        <h2>3. Purpose of Processing</h2>
        <p>We use personal data to:</p>
        <ul>
          <li>Provide the invoice digitization and management service</li>
          <li>Extract invoice data using artificial intelligence</li>
          <li>Automatically classify invoices as expense or income</li>
          <li>Generate exports (CSV, XLSX, ZIP) to facilitate accounting</li>
          <li>Manage subscriptions and payments via Apple In-App Purchase</li>
          <li>Send relevant push notifications about the service</li>
        </ul>

        <h2>4. Legal Basis</h2>
        <p>
          Processing is based on the performance of the service contract (art. 6.1.b GDPR) and,
          where applicable, user consent (art. 6.1.a GDPR) for optional features such as Gmail sync.
        </p>

        <h2>5. Storage and Security</h2>
        <ul>
          <li><strong>Invoice images:</strong> stored on Amazon Web Services (AWS) S3 with encryption at rest (AES-256).</li>
          <li><strong>User data and invoice records:</strong> stored in a PostgreSQL database with restricted access and encrypted connections (TLS).</li>
          <li><strong>Subscriptions:</strong> managed by RevenueCat; we do not store credit card data.</li>
        </ul>
        <p>
          We apply appropriate technical and organizational measures to protect personal data
          against unauthorized access, loss, or destruction.
        </p>

        <h2>6. Data Sharing with Third Parties</h2>
        <p>
          <strong>We do not sell personal data to third parties.</strong> Data is only shared with:
        </p>
        <ul>
          <li><strong>Anthropic (Claude API):</strong> invoice images and PDFs are sent to the Anthropic API for AI processing (extracting amounts, dates, vendor, etc.). Anthropic does not use this data to train its models. See the <a href="https://www.anthropic.com/legal/privacy" target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">Anthropic privacy policy</a>.</li>
          <li><strong>Amazon Web Services (AWS):</strong> as infrastructure provider (image and database hosting).</li>
          <li><strong>RevenueCat:</strong> for subscription management.</li>
          <li><strong>Apple:</strong> for authentication (Apple Sign-In) and payments (In-App Purchase).</li>
          <li><strong>Google:</strong> for authentication (Google OAuth) and, optionally, Gmail sync.</li>
        </ul>
        <p>
          All providers have GDPR-compliant data processing agreements.
        </p>

        <h2>7. International Transfers</h2>
        <p>
          Some of our service providers operate outside the European Economic Area (EEA). In those
          cases, we ensure appropriate safeguards are in place (such as Standard Contractual Clauses
          approved by the European Commission) to protect your data.
        </p>

        <h2>8. User Rights (GDPR)</h2>
        <p>Under the General Data Protection Regulation, you have the right to:</p>
        <ul>
          <li><strong>Access:</strong> request a copy of your personal data.</li>
          <li><strong>Rectification:</strong> correct inaccurate data.</li>
          <li><strong>Erasure:</strong> request deletion of your data (&ldquo;right to be forgotten&rdquo;).</li>
          <li><strong>Portability:</strong> receive your data in a structured, commonly used format.</li>
          <li><strong>Objection:</strong> object to processing under certain circumstances.</li>
          <li><strong>Restriction:</strong> request restriction of processing.</li>
        </ul>
        <p>
          To exercise these rights, contact us at{" "}
          <a href="mailto:info@kungfusoftware.es" className="text-primary hover:underline">info@kungfusoftware.es</a>.
          We will respond within a maximum of 30 days.
        </p>

        <h2>9. Account Deletion</h2>
        <p>
          You can delete your account directly from the App, in the Settings section. Upon
          deletion, all your personal data, invoices, and associated images will be permanently
          deleted within a maximum of 30 days.
        </p>

        <h2>10. Data Retention</h2>
        <p>
          We retain personal data while the user account is active. After account deletion, data
          is permanently erased within 30 days, unless legal retention obligations apply (e.g.,
          tax obligations).
        </p>

        <h2>11. Minors</h2>
        <p>
          The App is not directed to children under 16. We do not knowingly collect data from
          minors. If we detect that a minor has provided personal data, we will delete it immediately.
        </p>

        <h2>12. Cookies and Similar Technologies</h2>
        <p>
          The website may use essential cookies for its operation. We do not use tracking or
          advertising cookies.
        </p>

        <h2>13. Changes to This Policy</h2>
        <p>
          We reserve the right to modify this privacy policy. Any changes will be notified through
          the App or website. The last updated date is shown at the top of this document.
        </p>

        <h2>14. Supervisory Authority</h2>
        <p>
          If you believe the processing of your data is not appropriate, you may file a complaint
          with the Spanish Data Protection Agency (AEPD):{" "}
          <a href="https://www.aepd.es" target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">www.aepd.es</a>.
        </p>

        <h2>15. Contact</h2>
        <p>
          For any privacy-related inquiries, you can contact us at:
        </p>
        <ul>
          <li><strong>Company:</strong> Kung Fu Software SL</li>
          <li><strong>Email:</strong> <a href="mailto:info@kungfusoftware.es" className="text-primary hover:underline">info@kungfusoftware.es</a></li>
        </ul>
      </div>
    </div>
  );
}

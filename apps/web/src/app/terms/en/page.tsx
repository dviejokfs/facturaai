import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terms of Service - InvoScanAI",
  description: "Terms and conditions of use for InvoScanAI.",
};

export default function TermsPageEN() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-16 sm:px-6 sm:py-24">
      <h1 className="font-heading text-3xl font-bold tracking-tight sm:text-4xl">
        Terms of Service
      </h1>
      <p className="mt-4 text-sm text-muted-foreground">
        Last updated: April 9, 2026
      </p>

      <div className="prose prose-neutral mt-10 max-w-none text-foreground [&_h2]:font-heading [&_h2]:text-xl [&_h2]:font-semibold [&_h2]:mt-10 [&_h2]:mb-4 [&_h3]:font-heading [&_h3]:text-lg [&_h3]:font-semibold [&_h3]:mt-8 [&_h3]:mb-3 [&_p]:text-muted-foreground [&_p]:leading-relaxed [&_p]:mb-4 [&_ul]:text-muted-foreground [&_ul]:mb-4 [&_ul]:list-disc [&_ul]:pl-6 [&_ul]:space-y-2 [&_li]:leading-relaxed [&_ol]:text-muted-foreground [&_ol]:mb-4 [&_ol]:list-decimal [&_ol]:pl-6 [&_ol]:space-y-2">
        <h2>1. Service Provider</h2>
        <p>
          These Terms of Service (&ldquo;Terms&rdquo;) govern the use of the InvoScanAI mobile
          application (&ldquo;the App&rdquo;) and associated services, provided by:
        </p>
        <ul>
          <li><strong>Legal entity:</strong> Kung Fu Software SL</li>
          <li><strong>Contact email:</strong> <a href="mailto:info@kungfusoftware.es" className="text-primary hover:underline">info@kungfusoftware.es</a></li>
        </ul>

        <h2>2. Service Description</h2>
        <p>
          InvoScanAI is an invoice management application that uses artificial intelligence to:
        </p>
        <ul>
          <li>Scan and digitize invoices through the device camera</li>
          <li>Automatically extract key data (amounts, dates, tax IDs, line items)</li>
          <li>Classify invoices as expenses or income</li>
          <li>Allow data export in CSV, XLSX, and ZIP formats</li>
          <li>Sync invoices received by email (Gmail)</li>
        </ul>

        <h2>3. Acceptance of Terms</h2>
        <p>
          By downloading, installing, or using the App, the user accepts these Terms in their
          entirety. If you do not agree to any of the Terms, you must not use the App.
        </p>

        <h2>4. Registration and User Account</h2>
        <p>
          Using the App requires creating an account via Apple Sign-In or Google OAuth. The user
          is responsible for maintaining the confidentiality of their account and for all activities
          performed under it.
        </p>

        <h2>5. Plans and Subscriptions</h2>
        <h3>5.1 Free Plan</h3>
        <ul>
          <li>Up to 5 invoice scans per month</li>
          <li>Automatic AI classification</li>
          <li>CSV export</li>
        </ul>

        <h3>5.2 Pro Plan</h3>
        <ul>
          <li>Unlimited scans</li>
          <li>CSV, XLSX, and ZIP export</li>
          <li>Gmail sync</li>
          <li>Priority support</li>
        </ul>
        <p>
          The Pro Plan subscription is managed through Apple In-App Purchase. Price and renewal
          terms are displayed in the App Store before purchase.
        </p>
        <h3>5.3 Auto-Renewal</h3>
        <ul>
          <li>Payment will be charged to the user&rsquo;s Apple ID account at confirmation of purchase.</li>
          <li>The subscription automatically renews for the same period unless canceled at least 24 hours before the end of the current period.</li>
          <li>The account will be charged for renewal within 24 hours before the end of the current period, at the selected subscription price.</li>
          <li>The user can manage and cancel the subscription from their Apple account settings (Settings &rsaquo; [name] &rsaquo; Subscriptions) after purchase.</li>
          <li>No refunds are offered for periods already started; Apple&rsquo;s refund policies apply.</li>
        </ul>

        <h2>6. User Obligations</h2>
        <p>The user agrees to:</p>
        <ul>
          <li>Provide truthful and up-to-date data</li>
          <li>Use the App only to manage legitimate and legal invoices</li>
          <li>Not use the App for fraudulent or illegal purposes</li>
          <li>Not attempt to access other users&rsquo; data or Company systems in an unauthorized manner</li>
          <li>Comply with applicable tax legislation; the App is a management tool, not a tax advisor</li>
        </ul>

        <h2>7. Data Ownership</h2>
        <p>
          The user retains ownership of all data and invoices uploaded to the App. The Company
          claims no ownership rights over user content. By using the service, the user grants the
          Company a limited license to process data solely for the purpose of providing the service.
        </p>

        <h2>8. AI Accuracy</h2>
        <p>
          AI data extraction is automatic and may contain errors. The user is responsible for
          verifying the accuracy of extracted data before using it for accounting or tax purposes.
          The Company is not responsible for errors arising from automatic data extraction.
        </p>

        <h2>9. Service Availability</h2>
        <p>
          The Company strives to keep the App continuously available but does not guarantee 100%
          uptime. The service may be interrupted for maintenance, updates, or force majeure. The
          Company is not liable for losses resulting from temporary service unavailability.
        </p>

        <h2>10. Limitation of Liability</h2>
        <p>
          To the maximum extent permitted by law, the Company shall not be liable for:
        </p>
        <ul>
          <li>Indirect, incidental, or consequential damages arising from use of the App</li>
          <li>Data loss caused by the user or circumstances beyond the Company&rsquo;s control</li>
          <li>Tax or accounting decisions made based on data provided by the App</li>
        </ul>

        <h2>11. Intellectual Property</h2>
        <p>
          The App, its design, source code, trademarks, and content are the property of Kung Fu
          Software SL and are protected by intellectual and industrial property laws. The user
          acquires no rights over the Company&rsquo;s intellectual property by using the App.
        </p>

        <h2>12. Termination and Account Deletion</h2>
        <p>
          The user may delete their account at any time from the Settings section of the App.
          Upon deletion:
        </p>
        <ul>
          <li>Any active subscription will be canceled (the user must also cancel the subscription
            through Apple to avoid future charges)</li>
          <li>All personal data and invoices will be deleted within a maximum of 30 days</li>
        </ul>
        <p>
          The Company reserves the right to suspend or cancel accounts that violate these Terms,
          with prior notice to the user.
        </p>

        <h2>13. Changes to Terms</h2>
        <p>
          The Company reserves the right to modify these Terms at any time. Changes will be
          notified through the App or by email. Continued use of the App after notification of
          changes constitutes acceptance of the new Terms.
        </p>

        <h2>14. Governing Law and Jurisdiction</h2>
        <p>
          These Terms are governed by Spanish law. For the resolution of any dispute arising from
          these Terms, the parties submit to the courts of the city where the Company is domiciled,
          unless consumer protection law establishes a different jurisdiction.
        </p>

        <h2>15. Contact</h2>
        <p>
          For any inquiries regarding these Terms, you can contact us at:
        </p>
        <ul>
          <li><strong>Company:</strong> Kung Fu Software SL</li>
          <li><strong>Email:</strong> <a href="mailto:info@kungfusoftware.es" className="text-primary hover:underline">info@kungfusoftware.es</a></li>
        </ul>
      </div>
    </div>
  );
}

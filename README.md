# MailWeave
![](icon-small.png)

Current version: `0.3`


[![Xcode - Build and Analyze](https://github.com/dcoeurjo/MailWeave/actions/workflows/objective-c-xcode.yml/badge.svg)](https://github.com/dcoeurjo/MailWeave/actions/workflows/objective-c-xcode.yml)


MailWeave is a macOS application designed to synthesize personalized email drafts in Apple Mail from tabular (CSV) data. Given a CSV file, users map columns (for example, `email`, `name`, `company`) and provide a message template. MailWeave then instantiates one draft per recipient by resolving template placeholders with the corresponding row values.


![](snapshot.png)


Overview of workflow
- Import a CSV file (any delimiter is supported; the default is `;`) and map relevant headers.
- Select the composition mode: a single global template or per-recipient messages.
- Employ `{{header}}` placeholders (e.g., `{{name}}`, `{{company}}`) to parameterize subject and body content.
- Generate Mail.app drafts for subsequent inspection and sending.

For example, your CSV might look like this:
```csv
name,email,message
John Doe,john.doe@example.com,"Dear {{name}}, This is a test message for you."
Jane Smith,jane.smith@example.com,"Hi {{name}}, I hope this message finds you well."
Bob Johnson,bob.johnson@example.com,"Hello {{name}}, Thank you for your time."
Alice Williams,alice.williams@example.com,"Dear {{name}}, Looking forward to hearing from you."
```


## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.0 
- Mail.app configured with an email account

## Installation

1. Open the project in Xcode.
2. Build and run the project (⌘R).


## CSV Format

- The first row must be a header row.
- No specific header names are required.
- Before proceeding, select a header for `email`.
- Default CSV delimiter is `;` (semicolon).
- If message mode is `Per recipient`, selecting a `message` header is required.
- If message mode is `Global message`, `message` header mapping is not needed.
- If a `name` column exists, it is used for recipient display/personalization; otherwise MailWeave derives a fallback name from the email local-part.
- Additional headers are supported and can be referenced in the message template.

See example in `sample_recipients.csv`

## Message Personalization

You can use any header name as a placeholder in the subject, CC, or message body.

When editing the default message template, MailWeave displays the available headers.

Example:

```
Hi {{name}},

Thanks for your work at {{company}}.
```

## Author

David Coeurjolly (david.coeurjolly@cnrs.fr)

Bertrand Kerautret (bertrand.kerautret@univ-lyon2.fr)

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).

See [LICENSE.md](LICENSE.md) for more information.

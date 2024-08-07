
/* Controller responsible to save signature and generate pdf */

public class QuotePDFWithSignatureController {
    public Quote quote { get; set; }
    public Boolean pdfGenerated { get; set; }
    public Id quoteId { get; set; }
    public Id contentVersionId { get; set; }
    public String signatureUrl { get; set; }
    public String currentDate { get; set; }
    public String customerName { get; set; }
    
    // Constructor
    public QuotePDFWithSignatureController() {
        quoteId = ApexPages.currentPage().getParameters().get('id');
        if (quoteId != null) {
            quote = [SELECT Id, Name, Account.Name FROM Quote WHERE Id = :quoteId LIMIT 1];

        }
        currentDate = System.today().format();
        pdfGenerated = false;
        
    }

    // Action method to save signature and redirect
    public PageReference saveSignatureAndGeneratePDF() {
        String base64Data = ApexPages.currentPage().getParameters().get('signatureDataInput');
        if (String.isBlank(base64Data)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No signature data found.'));
            return null;
        }
        String base64Content = base64Data.split(',')[1];
        Blob signatureBlob = EncodingUtil.base64Decode(base64Content);

        // Insert signature as ContentVersion
        ContentVersion signatureContentVersion = new ContentVersion();
        signatureContentVersion.ContentLocation = 'S';
        signatureContentVersion.PathOnClient = 'Signature.png';
        signatureContentVersion.VersionData = signatureBlob;
        signatureContentVersion.FirstPublishLocationId = quoteId; // Link to the Quote record
        insert signatureContentVersion;

        // Get the Id of the inserted ContentVersion
        contentVersionId = [SELECT Id FROM ContentVersion WHERE Id = :signatureContentVersion.Id LIMIT 1].Id;
        signatureUrl = '/sfc/servlet.shepherd/version/download/' + contentVersionId;
        
        pdfGenerated = true;

        // Redirect to the PDF generation page
        PageReference pdfPage = new PageReference('/apex/RenderQuotePDFPage');
        pdfPage.getParameters().put('id', quoteId);
        pdfPage.getParameters().put('contentVersionId', contentVersionId);
        pdfPage.getParameters().put('signatureUrl', signatureUrl);
        pdfPage.getParameters().put('customerName', customerName);

        pdfPage.setRedirect(true);

        return pdfPage;
    }

    // Action method to generate and save PDF
    public PageReference generateAndSavePDF() {
        // Generate PDF content and save as ContentVersion
        Blob pdfBlob = createPDFWithSignature(contentVersionId, signatureUrl);

        // Insert PDF as ContentVersion
        ContentVersion pdfContentVersion = new ContentVersion();
        pdfContentVersion.ContentLocation = 'S';
        pdfContentVersion.PathOnClient = 'Quote_with_Signature.pdf';
        pdfContentVersion.VersionData = pdfBlob;
        pdfContentVersion.FirstPublishLocationId = quoteId; // Link to the Quote record
        insert pdfContentVersion;

        // Optionally, redirect to a success page or display a message
        return new PageReference('/'+ quote.Id);
    }

    private Blob createPDFWithSignature(Id contentVersionId, String signatureUrl) {
        PageReference pdfPage = Page.RenderQuotePDFPage;
        pdfPage.getParameters().put('id', quoteId);
        pdfPage.getParameters().put('contentVersionId', contentVersionId);
        pdfPage.getParameters().put('signatureUrl', signatureUrl);
        pdfPage.getParameters().put('customerName', customerName);


        Blob pdfBlob;
        try {
            pdfBlob = pdfPage.getContentAsPDF();
        } catch (VisualforceException e) {
            pdfBlob = Blob.valueOf('Error generating PDF: ' + e.getMessage());
        }
        return pdfBlob;
    }
}

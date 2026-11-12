<%@ Page Language="VB" AutoEventWireup="false" CodeFile="MobileChargesUpload.aspx.vb" Inherits="MobileChargesUpload" EnableEventValidation="true" EnableViewStateMac="true" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Publish mobile charges</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 1rem; }
        main { max-width: 50rem; margin: auto; }
        button, input { margin: .5rem 0; max-width: 100%; }
        .status { white-space: pre-wrap; } h1 { color: #006400; }
    </style>
</head>
<body>
<form runat="server" enctype="multipart/form-data">
    <main>
        <h1>Publish mobile charges</h1>
        <p>Upload the complete monthly Billing Data workbook (.xls/.xlsx, up to 10 MB).
        The file name must start with MM_YYYY. Validation does not change published data.</p>
        <asp:HiddenField ID="CsrfToken" runat="server" />
        <asp:Label runat="server" AssociatedControlID="WorkbookFile" Text="Monthly workbook" />
        <asp:FileUpload ID="WorkbookFile" runat="server" />
        <br />
        <asp:Button ID="ValidateButton" runat="server" Text="Validate workbook" OnClick="ValidateWorkbook" />
        <p class="status" role="status"><asp:Literal ID="StatusMessage" runat="server" Mode="Encode" /></p>
        <asp:Button ID="PublishButton" runat="server" Text="Confirm publication of validated snapshot" Visible="false" OnClick="PublishWorkbook" />
        <p><a href="rptMCMUserPeriodDetail.aspx">View my mobile charges</a></p>
    </main>
</form>
</body>
</html>

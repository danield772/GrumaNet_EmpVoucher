<%@ Page Language="VB" AutoEventWireup="false" CodeFile="rptMCMUserPeriodDetail.aspx.vb" Inherits="rptMCMUserPeriodDetail" EnableEventValidation="true" EnableViewStateMac="true" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Mobile Device Charges</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 1rem; color: #17251b; }
        main { max-width: 64rem; margin: auto; }
        h1 { color: #006400; } .table-wrap { overflow-x: auto; }
        table { border-collapse: collapse; width: 100%; }
        th, td { padding: .7rem; border: 1px solid #b9c9bd; text-align: left; }
        th { background: #e6f0e7; } a:focus { outline: 3px solid #006400; }
        .status { padding: 1rem 0; } nav { margin-top: 1rem; }
    </style>
</head>
<body>
<form runat="server">
    <main>
        <h1>Mobile Device Charges</h1>
        <p>Signed in as <asp:Literal ID="EmployeeContext" runat="server" Mode="Encode" /></p>
        <p><asp:Literal ID="BillingPeriod" runat="server" Mode="Encode" /></p>
        <p class="status" role="status"><asp:Literal ID="StatusMessage" runat="server" Mode="Encode" /></p>
        <div class="table-wrap">
            <asp:GridView ID="Assignments" runat="server" AutoGenerateColumns="false" EnableViewState="false" UseAccessibleHeader="true" Caption="Your mobile assignments">
                <Columns>
                    <asp:BoundField DataField="MobileNumber" HeaderText="Mobile number" HtmlEncode="true" />
                    <asp:BoundField DataField="MonthlyCharge" HeaderText="Monthly equipment payment charge" DataFormatString="{0:0.####}" HtmlEncode="true" />
                    <asp:BoundField DataField="ActivationDisplay" HeaderText="Activation date" HtmlEncode="true" />
                </Columns>
            </asp:GridView>
        </div>
        <nav><asp:HyperLink ID="ReturnLink" runat="server" Visible="false">Return to Asset Voucher</asp:HyperLink></nav>
    </main>
</form>
</body>
</html>

Option Strict On
Imports System
Imports System.Configuration
Imports System.Data.SqlClient
Imports System.Globalization
Imports MobileCharges

Partial Class rptMCMUserPeriodDetail
    Inherits System.Web.UI.Page

    Protected Sub Page_Init(sender As Object, e As EventArgs) Handles Me.Init
        Try
            Access.Prepare(Me)
        Catch ex As UnauthorizedAccessException
            Access.LogFailure("employee-authentication")
        End Try
    End Sub

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        Try
            Dim loginName As String = Access.Login(User.Identity)
            EmployeeContext.Text = loginName
            ConfigureReturnLink()
            Dim employee As String = Access.EmployeeNumber(loginName)
            Dim snapshot As Snapshot = Store.Current(employee)
            If Not snapshot.Period.HasValue Then
                StatusMessage.Text = "Mobile charges are unavailable: no billing period has been published."
                Return
            End If
            BillingPeriod.Text = "Billing period: " & snapshot.Period.Value.ToString("MMMM yyyy", CultureInfo.InvariantCulture)
            If snapshot.Rows.Count = 0 Then
                StatusMessage.Text = "No mobile assignments are listed for you for this billing period."
            Else
                Assignments.DataSource = snapshot.Rows
                Assignments.DataBind()
            End If
        Catch ex As UnauthorizedAccessException
            StatusMessage.Text = "Your corporate account could not be verified or linked to an employee number. No assignments were disclosed."
            Access.LogFailure("employee-identity")
        Catch ex As ConfigurationErrorsException
            StatusMessage.Text = "Mobile charges are not configured yet. Contact IT."
            Access.LogFailure("employee-configuration")
        Catch ex As SqlException
            StatusMessage.Text = "Mobile charges are temporarily unavailable. Please contact IT or try again later."
            Access.LogFailure("employee-database")
        End Try
    End Sub

    Private Sub ConfigureReturnLink()
        Dim url As String = ConfigurationManager.AppSettings("MobileChargesReturnUrl")
        If String.IsNullOrWhiteSpace(url) OrElse
            Not System.Text.RegularExpressions.Regex.IsMatch(url, "\A~/(?!/)[A-Za-z0-9_./-]+\.aspx\z") OrElse
            url.Contains("..") Then
            Throw New ConfigurationErrorsException("A local Asset Voucher return path is required.")
        End If
        ReturnLink.NavigateUrl = url
        ReturnLink.Visible = True
    End Sub

    Protected Sub Page_Error(sender As Object, e As EventArgs) Handles Me.Error
        Access.LogFailure("employee-unexpected")
        Server.ClearError()
        Response.Clear()
        Response.StatusCode = 500
        Response.TrySkipIisCustomErrors = True
        Response.ContentType = "text/plain"
        Response.Write("Mobile charges could not be loaded. Contact IT or try again later.")
    End Sub
End Class

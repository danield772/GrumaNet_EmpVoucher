Option Strict On
Imports System
Imports System.Configuration
Imports System.Data.SqlClient
Imports System.IO
Imports System.Web
Imports MobileCharges

Partial Class MobileChargesUpload
    Inherits System.Web.UI.Page
    Private Const BatchKey As String = "MobileCharges.ValidatedBatch"
    Private Const TokenKey As String = "MobileCharges.Csrf"
    Private AuthorizedLogin As String

    Protected Sub Page_Init(sender As Object, e As EventArgs) Handles Me.Init
        Try
            Access.Prepare(Me)
            AuthorizedLogin = Access.Login(User.Identity)
            If Not Access.IsPublisher(AuthorizedLogin) Then Throw New UnauthorizedAccessException()
            If Session(TokenKey) Is Nothing Then Session(TokenKey) = Guid.NewGuid().ToString("N")
            If IsPostBack AndAlso Not String.Equals(
                Request.Form(CsrfToken.UniqueID), CStr(Session(TokenKey)), StringComparison.Ordinal) Then
                Throw New UnauthorizedAccessException()
            End If
        Catch ex As UnauthorizedAccessException
            Access.LogFailure("publisher-authorization")
            Throw New HttpException(403, "You are not authorized to publish mobile charges.")
        End Try
    End Sub

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        CsrfToken.Value = CStr(Session(TokenKey))
        Dim batch As ValidatedBatch = TryCast(Session(BatchKey), ValidatedBatch)
        PublishButton.Visible = batch IsNot Nothing AndAlso
            String.Equals(batch.Owner, AuthorizedLogin, StringComparison.OrdinalIgnoreCase)
    End Sub

    Protected Sub ValidateWorkbook(sender As Object, e As EventArgs)
        Session.Remove(BatchKey)
        PublishButton.Visible = False
        Try
            If Not WorkbookFile.HasFile Then Throw New InputException("Select a workbook first.")
            If WorkbookFile.PostedFile.ContentLength > Workbook.MaxBytes Then Throw New InputException("The workbook exceeds 10 MB.")
            ' Bounded in-memory processing avoids retaining raw files or exposing them under the web root.
            Dim batch As ValidatedBatch = Workbook.Read(
                WorkbookFile.PostedFile.InputStream, WorkbookFile.FileName, AuthorizedLogin)
            Session(BatchKey) = batch
            PublishButton.Visible = True
            StatusMessage.Text = "Validated " & batch.Rows.Count.ToString() & " assignments for " &
                batch.Period.ToString("MMMM yyyy", System.Globalization.CultureInfo.InvariantCulture) &
                ". Confirm publication to replace the complete current snapshot."
        Catch ex As InputException
            StatusMessage.Text = ex.Message
            Access.LogFailure("workbook-validation")
        Catch ex As ExcelDataReader.Exceptions.ExcelReaderException
            StatusMessage.Text = "The workbook could not be read. Check the file format and remove password protection."
            Access.LogFailure("workbook-format")
        Catch ex As InvalidDataException
            StatusMessage.Text = "The workbook archive is invalid."
            Access.LogFailure("workbook-archive")
        Catch ex As IOException
            StatusMessage.Text = "The upload could not be read. Upload the workbook again."
            Access.LogFailure("workbook-io")
        End Try
    End Sub

    Protected Sub PublishWorkbook(sender As Object, e As EventArgs)
        Try
            Dim batch As ValidatedBatch = TryCast(Session(BatchKey), ValidatedBatch)
            If batch Is Nothing Then Throw New InputException("The preview has expired. Validate the workbook again.")
            Store.Publish(batch, Access.Login(User.Identity))
            Session.Remove(BatchKey)
            PublishButton.Visible = False
            StatusMessage.Text = "Published billing period " & batch.Period.ToString("MMMM yyyy", System.Globalization.CultureInfo.InvariantCulture) & "."
        Catch ex As InputException
            StatusMessage.Text = ex.Message
            Access.LogFailure("publication-validation")
        Catch ex As UnauthorizedAccessException
            StatusMessage.Text = "You are not authorized to publish this snapshot."
            Access.LogFailure("publication-authorization")
        Catch ex As ConfigurationErrorsException
            StatusMessage.Text = "Publication is not configured. Contact IT. The existing snapshot was not replaced."
            Access.LogFailure("publication-configuration")
        Catch ex As SqlException
            StatusMessage.Text = "Publication could not be confirmed. Reload the employee view to verify the current period before retrying."
            Access.LogFailure("publication-database")
        End Try
    End Sub

    Protected Sub Page_Error(sender As Object, e As EventArgs) Handles Me.Error
        Dim failure As HttpException = TryCast(Server.GetLastError(), HttpException)
        Dim denied As Boolean = failure IsNot Nothing AndAlso failure.GetHttpCode() = 403
        Access.LogFailure("publisher-request-failed")
        Server.ClearError()
        Response.Clear()
        Response.StatusCode = If(denied, 403, 500)
        Response.TrySkipIisCustomErrors = True
        Response.ContentType = "text/plain"
        Response.Write(If(denied, "You are not authorized to publish mobile charges.",
            "The request could not be completed. Contact IT. Verify the current published period before retrying."))
    End Sub
End Class

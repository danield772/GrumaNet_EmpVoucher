Option Strict On
Imports System
Imports System.Configuration
Imports System.Data
Imports System.Data.SqlClient
Imports System.Security.Principal
Imports System.Web
Imports System.Web.UI

Namespace MobileCharges
    Public Module Access
        Public Function Login(identity As IIdentity) As String
            If identity Is Nothing OrElse Not identity.IsAuthenticated OrElse
                String.IsNullOrWhiteSpace(identity.Name) OrElse identity.Name.Length > 256 Then
                Throw New UnauthorizedAccessException()
            End If
            Return identity.Name
        End Function

        Public Function IsPublisher(loginName As String) As Boolean
            Dim setting As String = ConfigurationManager.AppSettings("MobileChargesPublishers")
            If String.IsNullOrWhiteSpace(setting) Then Return False
            For Each entry As String In setting.Split(";"c)
                If String.Equals(entry.Trim(), loginName, StringComparison.OrdinalIgnoreCase) Then Return True
            Next
            Return False
        End Function

        Public Function Connection(name As String) As SqlConnection
            Dim setting As ConnectionStringSettings = ConfigurationManager.ConnectionStrings(name)
            If setting Is Nothing OrElse String.IsNullOrWhiteSpace(setting.ConnectionString) Then
                Throw New ConfigurationErrorsException("Mobile charges connection is not configured.")
            End If
            Return New SqlConnection(setting.ConnectionString)
        End Function

        Public Function EmployeeNumber(loginName As String) As String
            Using connection As SqlConnection = Access.Connection("MobileChargesIdentityConnectionString")
                Using command As New SqlCommand("dbo.MobileChargesResolveEmployee", connection)
                    command.CommandType = CommandType.StoredProcedure
                    command.Parameters.Add("@Login", SqlDbType.NVarChar, 256).Value = loginName
                    connection.Open()
                    Using reader As SqlDataReader = command.ExecuteReader()
                        If Not reader.Read() OrElse reader.IsDBNull(0) Then Throw New UnauthorizedAccessException()
                        Dim employee As String = Convert.ToString(reader.GetValue(0), System.Globalization.CultureInfo.InvariantCulture).Trim()
                        If String.IsNullOrWhiteSpace(employee) OrElse employee.Length > 64 OrElse reader.Read() Then
                            Throw New UnauthorizedAccessException()
                        End If
                        Return employee
                    End Using
                End Using
            End Using
        End Function

        Public Sub Prepare(page As Page)
            Dim loginName As String = Login(page.User.Identity)
            page.ViewStateUserKey = page.Session.SessionID & ":" & loginName
            page.Response.Cache.SetCacheability(HttpCacheability.NoCache)
            page.Response.Cache.SetNoStore()
            page.Response.Headers("X-Content-Type-Options") = "nosniff"
            page.Response.Headers("X-Frame-Options") = "SAMEORIGIN"
        End Sub

        Public Sub LogFailure(code As String)
            ' Fixed event codes only: SQL exceptions can contain employee data and credentials.
            Diagnostics.Trace.TraceError("MobileCharges failure: " & code)
        End Sub
    End Module
End Namespace

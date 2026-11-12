Option Strict On
Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Data.SqlClient
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Xml

Namespace MobileCharges
    Public Module Store
        Public Function Current(employee As String) As Snapshot
            Dim snapshot As New Snapshot()
            Using connection As SqlConnection = Access.Connection("MobileChargesConnectionString")
                Using command As New SqlCommand("mobile.ReadEmployee", connection)
                    command.CommandType = CommandType.StoredProcedure
                    command.Parameters.Add("@EmployeeNumber", SqlDbType.NVarChar, 64).Value = employee
                    connection.Open()
                    Using reader As SqlDataReader = command.ExecuteReader()
                        If reader.Read() AndAlso Not reader.IsDBNull(0) Then snapshot.Period = reader.GetDateTime(0)
                        If reader.NextResult() Then
                            While reader.Read()
                                snapshot.Rows.Add(New Assignment With {
                                    .MobileNumber = reader.GetString(0),
                                    .MonthlyCharge = reader.GetDecimal(1),
                                    .ActivationDate = If(reader.IsDBNull(2), New Nullable(Of DateTime)(), reader.GetDateTime(2))})
                            End While
                        End If
                    End Using
                End Using
            End Using
            Return snapshot
        End Function

        Public Sub Publish(batch As ValidatedBatch, loginName As String)
            If Not Access.IsPublisher(loginName) OrElse
                Not String.Equals(batch.Owner, loginName, StringComparison.OrdinalIgnoreCase) Then
                Throw New UnauthorizedAccessException()
            End If
            If batch.Rows.Count > Workbook.MaxRows Then Throw New InputException("The validated batch has an invalid row count.")
            Dim phones As New HashSet(Of String)(StringComparer.Ordinal)
            For index As Integer = 0 To batch.Rows.Count - 1
                Rules.Validate(batch.Rows(index), phones, index + 2)
            Next
            Using connection As SqlConnection = Access.Connection("MobileChargesPublisherConnectionString")
                Using command As New SqlCommand("mobile.Publish", connection)
                    command.CommandType = CommandType.StoredProcedure
                    command.CommandTimeout = 60
                    command.Parameters.Add("@BatchId", SqlDbType.UniqueIdentifier).Value = batch.Id
                    command.Parameters.Add("@Period", SqlDbType.DateTime).Value = batch.Period
                    command.Parameters.Add("@FileName", SqlDbType.NVarChar, 200).Value = batch.FileName
                    command.Parameters.Add("@Publisher", SqlDbType.NVarChar, 256).Value = loginName
                    command.Parameters.Add("@Rows", SqlDbType.Xml).Value = SerializeRows(batch.Rows)
                    connection.Open()
                    Try
                        command.ExecuteNonQuery()
                    Catch ex As SqlException
                        If ex.Number = 50001 Then Throw New InputException("A newer billing period has already been published. Validate a current or later workbook.")
                        Throw
                    End Try
                End Using
            End Using
        End Sub

        Public Function SerializeRows(rows As IEnumerable(Of Assignment)) As String
            Dim text As New StringBuilder()
            Using writer As XmlWriter = XmlWriter.Create(text, New XmlWriterSettings With {.OmitXmlDeclaration = True})
                writer.WriteStartElement("rows")
                For Each row As Assignment In rows
                    writer.WriteStartElement("row")
                    writer.WriteAttributeString("employee", row.EmployeeNumber)
                    writer.WriteAttributeString("phone", row.MobileNumber)
                    writer.WriteAttributeString("phoneKey", Rules.PhoneKey(row.MobileNumber))
                    writer.WriteAttributeString("charge", row.MonthlyCharge.ToString(CultureInfo.InvariantCulture))
                    If row.ActivationDate.HasValue Then writer.WriteAttributeString("activation", row.ActivationDate.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture))
                    writer.WriteEndElement()
                Next
                writer.WriteEndElement()
            End Using
            Return text.ToString()
        End Function
    End Module
End Namespace

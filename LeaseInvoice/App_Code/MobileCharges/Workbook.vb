Option Strict On
Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.IO.Compression
Imports ExcelDataReader

Namespace MobileCharges
    Public Module Workbook
        Public Const MaxBytes As Integer = 10 * 1024 * 1024
        Public Const MaxRows As Integer = 20000
        Private ReadOnly Headers As String() = {
            "Description 2 - Emp Number", "Mobile Number",
            "Equipment Payment Plan Charges", "Activation Date"}

        Public Function Read(stream As Stream, fileName As String, owner As String) As ValidatedBatch
            Dim name As String = Path.GetFileName(fileName)
            Dim period As DateTime = Rules.ParsePeriod(name)
            If name.Length > 200 Then Throw New InputException("The file name is too long.")
            Dim extension As String = Path.GetExtension(name).ToLowerInvariant()
            If extension <> ".xls" AndAlso extension <> ".xlsx" Then
                Throw New InputException("Upload an .xls or .xlsx workbook.")
            End If
            If Not stream.CanSeek OrElse stream.Length = 0 OrElse stream.Length > MaxBytes Then
                Throw New InputException("The workbook must be nonempty and no larger than 10 MB.")
            End If
            ValidateContainer(stream, extension)
            Dim batch As New ValidatedBatch With {
                .Id = Guid.NewGuid(), .Period = period, .FileName = name,
                .Owner = owner, .Rows = New List(Of Assignment)()}
            Dim config As New ExcelReaderConfiguration With {.LeaveOpen = True}
            Using excel As IExcelDataReader = ExcelReaderFactory.CreateReader(stream, config)
                Dim sheets As Integer = 0
                Do
                    sheets += 1
                    If sheets > 32 Then Throw New InputException("The workbook exceeds the 32-sheet limit.")
                    If excel.Name = "Billing Data" Then
                        ReadSheet(excel, batch.Rows)
                        Return batch
                    End If
                Loop While excel.NextResult()
            End Using
            Throw New InputException("The Billing Data worksheet is missing.")
        End Function

        Private Sub ValidateContainer(stream As Stream, extension As String)
            Dim signature(7) As Byte
            Dim count As Integer = stream.Read(signature, 0, signature.Length)
            stream.Position = 0
            Dim binary As Boolean = count = 8 AndAlso
                BitConverter.ToString(signature) = "D0-CF-11-E0-A1-B1-1A-E1"
            If extension = ".xls" Then
                If Not binary Then Throw New InputException("The file content does not match .xls.")
                Return
            End If
            If count < 4 OrElse signature(0) <> &H50 OrElse signature(1) <> &H4B Then
                Throw New InputException("The file content does not match .xlsx.")
            End If
            Using archive As New ZipArchive(stream, ZipArchiveMode.Read, True)
                If archive.Entries.Count > 2000 Then Throw New InputException("The workbook contains too many archive entries.")
                Dim expanded As Long = 0
                Dim actualExpanded As Long = 0
                Dim buffer(65535) As Byte
                For Each entry As ZipArchiveEntry In archive.Entries
                    expanded += entry.Length
                    If expanded > 64L * 1024 * 1024 Then
                        Throw New InputException("The workbook exceeds the 64 MB expanded-size limit.")
                    End If
                    Using content As Stream = entry.Open()
                        Dim actualEntry As Long = 0
                        Dim readCount As Integer = content.Read(buffer, 0, buffer.Length)
                        While readCount > 0
                            actualEntry += readCount
                            actualExpanded += readCount
                            If actualExpanded > 64L * 1024 * 1024 Then
                                Throw New InputException("The workbook exceeds the 64 MB expanded-size limit.")
                            End If
                            readCount = content.Read(buffer, 0, buffer.Length)
                        End While
                        If actualEntry <> entry.Length Then Throw New InputException("The workbook archive has inconsistent entry sizes.")
                    End Using
                Next
            End Using
            stream.Position = 0
        End Sub

        Private Sub ReadSheet(excel As IExcelDataReader, rows As List(Of Assignment))
            If Not excel.Read() OrElse excel.FieldCount > 128 Then
                Throw New InputException("Billing Data must start with a header row and contain at most 128 columns.")
            End If
            Dim columns As New Dictionary(Of String, Integer)(StringComparer.Ordinal)
            For index As Integer = 0 To excel.FieldCount - 1
                Dim header As String = Convert.ToString(excel.GetValue(index), CultureInfo.InvariantCulture)
                If Array.IndexOf(Headers, header) >= 0 Then
                    If columns.ContainsKey(header) Then Throw New InputException("A required column header is duplicated.")
                    columns.Add(header, index)
                End If
            Next
            For Each header As String In Headers
                If Not columns.ContainsKey(header) Then Throw New InputException("Missing required column: " & header)
            Next
            Dim phones As New HashSet(Of String)(StringComparer.Ordinal)
            Dim rowNumber As Integer = 1
            While excel.Read()
                rowNumber += 1
                If rowNumber > MaxRows + 1 Then Throw New InputException("Billing Data exceeds 20,000 rows.")
                Dim empty As Boolean = True
                For Each column As Integer In columns.Values
                    If Not String.IsNullOrWhiteSpace(Convert.ToString(excel.GetValue(column), CultureInfo.InvariantCulture)) Then empty = False
                Next
                If empty Then Continue While
                Dim prefix As String = "Row " & rowNumber.ToString(CultureInfo.InvariantCulture) & ": "
                Dim charge As Decimal
                Dim value As Object = excel.GetValue(columns(Headers(2)))
                If TypeOf value Is Boolean OrElse Not Decimal.TryParse(
                    Convert.ToString(value, CultureInfo.InvariantCulture),
                    NumberStyles.AllowLeadingSign Or NumberStyles.AllowDecimalPoint,
                    CultureInfo.InvariantCulture, charge) Then
                    Throw New InputException(prefix & "Equipment Payment Plan Charges must be a number (zero is allowed).")
                End If
                Dim activation As Nullable(Of DateTime) = Nothing
                value = excel.GetValue(columns(Headers(3)))
                If value IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(Convert.ToString(value, CultureInfo.InvariantCulture)) Then
                    If TypeOf value Is DateTime Then
                        activation = DirectCast(value, DateTime).Date
                    Else
                        Dim parsed As DateTime
                        If Not DateTime.TryParseExact(Convert.ToString(value, CultureInfo.InvariantCulture),
                            New String() {"yyyy-MM-dd", "M/d/yyyy", "MM/dd/yyyy"},
                            CultureInfo.InvariantCulture, DateTimeStyles.None, parsed) Then
                            Throw New InputException(prefix & "Activation Date must be an Excel date or yyyy-MM-dd / M/d/yyyy, or blank.")
                        End If
                        activation = parsed.Date
                    End If
                End If
                Dim row As New Assignment With {
                    .EmployeeNumber = Identifier(excel, columns(Headers(0)), prefix),
                    .MobileNumber = Identifier(excel, columns(Headers(1)), prefix),
                    .MonthlyCharge = charge, .ActivationDate = activation}
                Rules.Validate(row, phones, rowNumber)
                rows.Add(row)
            End While
        End Sub

        Private Function Identifier(excel As IExcelDataReader, index As Integer, prefix As String) As String
            Dim value As Object = excel.GetValue(index)
            If value Is Nothing Then Return ""
            If TypeOf value Is String Then Return DirectCast(value, String).Trim()
            If TypeOf value Is Double Then
                Dim number As Double = DirectCast(value, Double)
                If number < 0 OrElse number > 999999999999999R OrElse Math.Truncate(number) <> number Then
                    Throw New InputException(prefix & "store employee and phone identifiers as text.")
                End If
                Dim format As String = excel.GetNumberFormatString(index)
                If format IsNot Nothing AndAlso System.Text.RegularExpressions.Regex.IsMatch(format, "^0{1,64}$") Then
                    Return number.ToString(format, CultureInfo.InvariantCulture)
                End If
                If format <> "General" AndAlso format <> "0" AndAlso format IsNot Nothing Then
                    Throw New InputException(prefix & "store formatted employee and phone identifiers as text to preserve their characters.")
                End If
                Return number.ToString("0", CultureInfo.InvariantCulture)
            End If
            Throw New InputException(prefix & "employee and phone identifiers must be text or whole numbers.")
        End Function
    End Module
End Namespace

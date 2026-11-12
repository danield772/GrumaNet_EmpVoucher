Option Strict On
Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.IO.Compression
Imports System.Security.Principal
Imports System.Text
Imports System.Xml
Imports MobileCharges

Module MobileChargesTests
    Private Passed As Integer
    Sub Main()
        Check(Rules.ParsePeriod("09_2026 Carrier 123-106.xlsx") = New DateTime(2026, 9, 1), "period prefix")
        Check(Rules.ParsePeriod("09_2026 Carrier 123-107.xlsx") = New DateTime(2026, 9, 1), "version does not change period")
        Reject(Sub() Rules.ParsePeriod("13_2026.xlsx"), "invalid month")
        Reject(Sub() Rules.ParsePeriod("09_20260.xlsx"), "invalid year boundary")
        Reject(Sub() Rules.ParsePeriod("09_0000.xlsx"), "invalid year")
        Reject(Sub() Rules.ParsePeriod("09_1600.xlsx"), "SQL datetime year bound")
        Dim row As New Assignment With {.EmployeeNumber = "0001", .MobileNumber = "+1 (555) 000-0100", .MonthlyCharge = 0D}
        Rules.Validate(row, New HashSet(Of String)(), 2)
        Check(row.ActivationDisplay = "Not available", "blank activation accepted")
        Check(row.MobileNumber = "+1 (555) 000-0100", "phone display preserved")
        Dim phones As New HashSet(Of String)()
        Rules.Validate(row, phones, 2)
        row.MobileNumber = "15550000100"
        Reject(Sub() Rules.Validate(row, phones, 3), "formatted duplicate rejected")
        row.MobileNumber = "5550000101"
        row.MonthlyCharge = 0.00001D
        Reject(Sub() Rules.Validate(row, New HashSet(Of String)(), 2), "precision")
        row.MonthlyCharge = 1000000000000000D
        Reject(Sub() Rules.Validate(row, New HashSet(Of String)(), 2), "charge overflow")
        row.MonthlyCharge = 0
        row.EmployeeNumber = ""
        Reject(Sub() Rules.Validate(row, New HashSet(Of String)(), 2), "missing employee")
        row.EmployeeNumber = "0001"
        row.MobileNumber = "not-a-phone"
        Reject(Sub() Rules.Validate(row, New HashSet(Of String)(), 2), "invalid phone")
        Dim identity As New GenericIdentity("DOMAIN\test")
        Check(Access.Login(identity) = "DOMAIN\test", "authenticated login")
        Try
            Access.Login(New GenericIdentity(""))
            Throw New Exception("Unauthenticated identity was accepted.")
        Catch ex As UnauthorizedAccessException
            Passed += 1
        End Try
        Check(Not Access.IsPublisher("DOMAIN\test"), "publisher denied when unconfigured")
        Dim headers As String() = {"Description 2 - Emp Number", "Mobile Number", "Equipment Payment Plan Charges", "Activation Date"}
        Using stream As MemoryStream = Fixture(headers, New String() {"0001", "+1 (555) 000-0100", "0", ""})
            Dim batch As ValidatedBatch = Workbook.Read(stream, "09_2026 Carrier-106.xlsx", "DOMAIN\test")
            Check(batch.Rows.Count = 1, "read one assignment")
            Check(batch.Rows(0).EmployeeNumber = "0001", "employee leading zeros")
            Check(batch.Rows(0).MonthlyCharge = 0D, "zero charge")
            Check(Not batch.Rows(0).ActivationDate.HasValue, "nullable activation")
        End Using
        Using stream As MemoryStream = Fixture(headers, New String() {"0001", "5550000100", "12.34", "2020-03-01"})
            Check(Workbook.Read(stream, "09_2026.xlsx", "DOMAIN\test").Rows(0).ActivationDate.Value = New DateTime(2020, 3, 1), "activation distinct from period")
        End Using
        Using stream As MemoryStream = Fixture(headers, New String() {"0001", "5550000100", "12.34", "invalid"})
            Reject(Sub() Workbook.Read(stream, "09_2026.xlsx", "DOMAIN\test"), "invalid activation")
        End Using
        Using stream As MemoryStream = Fixture(headers, New String() {"0001", "5550000100", "", ""})
            Reject(Sub() Workbook.Read(stream, "09_2026.xlsx", "DOMAIN\test"), "missing charge")
        End Using
        Using stream As MemoryStream = Fixture(headers, New String() {"0001", "5550000100", "1", ""}, True)
            Reject(Sub() Workbook.Read(stream, "09_2026.xlsx", "DOMAIN\test"), "workbook duplicate")
        End Using
        Dim wrong As String() = {"Employee", "Mobile Number", "Equipment Payment Plan Charges", "Activation Date"}
        Using stream As MemoryStream = Fixture(wrong, New String() {"0001", "5550000100", "1", ""})
            Reject(Sub() Workbook.Read(stream, "09_2026.xlsx", "DOMAIN\test"), "missing header")
        End Using
        Using stream As MemoryStream = Fixture(headers, New String() {"0001", "5550000100", "1", ""})
            Reject(Sub() Workbook.Read(stream, "09_2026.xls", "DOMAIN\test"), "extension/content mismatch")
        End Using
        Using stream As MemoryStream = Fixture(headers, New String() {"0001", "5550000100", "1", ""}, False, "Wrong sheet")
            Reject(Sub() Workbook.Read(stream, "09_2026.xlsx", "DOMAIN\test"), "missing worksheet")
        End Using
        Using stream As MemoryStream = Fixture(headers, Nothing)
            Check(Workbook.Read(stream, "09_2026.xlsx", "DOMAIN\test").Rows.Count = 0, "complete empty snapshot")
        End Using
        Using stream As MemoryStream = Fixture(headers, New String() {"0001", "5550000100", "1.25", ""}, False, "Billing Data", True)
            Dim parsed As Assignment = Workbook.Read(stream, "09_2026.xlsx", "DOMAIN\test").Rows(0)
            Check(parsed.MonthlyCharge = 1.25D, "native Excel numeric charge")
        End Using
        Using stream As New MemoryStream(New Byte(Workbook.MaxBytes) {})
            Reject(Sub() Workbook.Read(stream, "09_2026.xlsx", "DOMAIN\test"), "upload size bound")
        End Using
        Using stream As New MemoryStream()
            Using archive As New ZipArchive(stream, ZipArchiveMode.Create, True)
                Using content As Stream = archive.CreateEntry("oversized.xml").Open()
                    Dim block(65535) As Byte
                    For index As Integer = 0 To 1024
                        content.Write(block, 0, block.Length)
                    Next
                End Using
            End Using
            stream.Position = 0
            Reject(Sub() Workbook.Read(stream, "09_2026.xlsx", "DOMAIN\test"), "expanded workbook bound")
        End Using
        Using stream As MemoryStream = Fixture(New String() {headers(0), headers(0), headers(2), headers(3)}, Nothing)
            Reject(Sub() Workbook.Read(stream, "09_2026.xlsx", "DOMAIN\test"), "duplicate header")
        End Using
        row.MobileNumber = "5550000100"
        row.EmployeeNumber = New String("E"c, 65)
        Reject(Sub() Rules.Validate(row, New HashSet(Of String)(), 2), "identifier length bound")
        row.MobileNumber = "5550000100"
        row.EmployeeNumber = "EMP<&"""
        Dim doc As New XmlDocument()
        doc.LoadXml(Store.SerializeRows(New Assignment() {row}))
        Check(doc.DocumentElement.FirstChild.Attributes("employee").Value = row.EmployeeNumber, "XML safely escaped")
        Console.WriteLine("PASS: " & Passed.ToString(CultureInfo.InvariantCulture) & " mobile charges assertions.")
    End Sub

    Private Sub Check(condition As Boolean, label As String)
        If Not condition Then Throw New Exception("FAIL: " & label)
        Passed += 1
    End Sub

    Private Sub Reject(action As Action, label As String)
        Try
            action()
        Catch ex As InputException
            Passed += 1
            Return
        End Try
        Throw New Exception("FAIL: expected validation error for " & label)
    End Sub

    Private Function Fixture(headers As String(), values As String(), Optional duplicate As Boolean = False,
                             Optional sheetName As String = "Billing Data", Optional numericCharge As Boolean = False) As MemoryStream
        Dim stream As New MemoryStream()
        Using zip As New ZipArchive(stream, ZipArchiveMode.Create, True)
            Entry(zip, "[Content_Types].xml", "<Types xmlns=""http://schemas.openxmlformats.org/package/2006/content-types""><Default Extension=""rels"" ContentType=""application/vnd.openxmlformats-package.relationships+xml""/><Default Extension=""xml"" ContentType=""application/xml""/><Override PartName=""/xl/workbook.xml"" ContentType=""application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml""/><Override PartName=""/xl/worksheets/sheet1.xml"" ContentType=""application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml""/></Types>")
            Entry(zip, "_rels/.rels", "<Relationships xmlns=""http://schemas.openxmlformats.org/package/2006/relationships""><Relationship Id=""rId1"" Type=""http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"" Target=""xl/workbook.xml""/></Relationships>")
            Entry(zip, "xl/workbook.xml", "<workbook xmlns=""http://schemas.openxmlformats.org/spreadsheetml/2006/main"" xmlns:r=""http://schemas.openxmlformats.org/officeDocument/2006/relationships""><sheets><sheet name=""" & sheetName & """ sheetId=""1"" r:id=""rId1""/></sheets></workbook>")
            Entry(zip, "xl/_rels/workbook.xml.rels", "<Relationships xmlns=""http://schemas.openxmlformats.org/package/2006/relationships""><Relationship Id=""rId1"" Type=""http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"" Target=""worksheets/sheet1.xml""/></Relationships>")
            Dim sheet As New StringBuilder()
            Using xml As XmlWriter = XmlWriter.Create(sheet, New XmlWriterSettings With {.OmitXmlDeclaration = True})
                xml.WriteStartElement("worksheet", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
                xml.WriteStartElement("sheetData")
                WriteRow(xml, 1, headers)
                If values IsNot Nothing Then
                    WriteRow(xml, 2, values, numericCharge)
                    If duplicate Then WriteRow(xml, 3, values, numericCharge)
                End If
                xml.WriteEndElement()
                xml.WriteEndElement()
            End Using
            Entry(zip, "xl/worksheets/sheet1.xml", sheet.ToString())
        End Using
        stream.Position = 0
        Return stream
    End Function

    Private Sub Entry(zip As ZipArchive, path As String, content As String)
        Using writer As New StreamWriter(zip.CreateEntry(path).Open(), New UTF8Encoding(False))
            writer.Write(content)
        End Using
    End Sub

    Private Sub WriteRow(xml As XmlWriter, number As Integer, values As String(), Optional numericCharge As Boolean = False)
        xml.WriteStartElement("row")
        xml.WriteAttributeString("r", number.ToString(CultureInfo.InvariantCulture))
        For index As Integer = 0 To values.Length - 1
            xml.WriteStartElement("c")
            xml.WriteAttributeString("r", ChrW(65 + index) & number.ToString(CultureInfo.InvariantCulture))
            If numericCharge AndAlso index = 2 Then
                xml.WriteAttributeString("t", "n")
                xml.WriteElementString("v", values(index))
            Else
                xml.WriteAttributeString("t", "inlineStr")
                xml.WriteStartElement("is")
                xml.WriteElementString("t", values(index))
                xml.WriteEndElement()
            End If
            xml.WriteEndElement()
        Next
        xml.WriteEndElement()
    End Sub
End Module

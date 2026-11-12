Option Strict On
Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Text.RegularExpressions

Namespace MobileCharges
    <Serializable>
    Public Class Assignment
        Public Property EmployeeNumber As String
        Public Property MobileNumber As String
        Public Property MonthlyCharge As Decimal
        Public Property ActivationDate As Nullable(Of DateTime)

        Public ReadOnly Property ActivationDisplay As String
            Get
                If Not ActivationDate.HasValue Then Return "Not available"
                Return ActivationDate.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
            End Get
        End Property
    End Class

    <Serializable>
    Public Class ValidatedBatch
        Public Property Id As Guid
        Public Property Period As DateTime
        Public Property FileName As String
        Public Property Owner As String
        Public Property Rows As List(Of Assignment)
    End Class

    Public Class Snapshot
        Public Property Period As Nullable(Of DateTime)
        Public Property Rows As New List(Of Assignment)
    End Class

    Public Class InputException
        Inherits Exception
        Public Sub New(message As String)
            MyBase.New(message)
        End Sub
    End Class

    Public Module Rules
        Public Function ParsePeriod(fileName As String) As DateTime
            Dim match As Match = Regex.Match(fileName, "^(0[1-9]|1[0-2])_([0-9]{4})(?=\s|_|-|\.)")
            Dim period As DateTime
            If Not match.Success OrElse Not DateTime.TryParseExact(
                match.Value, "MM_yyyy", CultureInfo.InvariantCulture, DateTimeStyles.None, period) Then
                Throw New InputException("The file name must start with a valid MM_YYYY billing period.")
            End If
            If period.Year < 1753 Then Throw New InputException("The billing year must be at least 1753.")
            Return period
        End Function

        Public Function PhoneKey(phone As String) As String
            Return Regex.Replace(phone, "[\s()+.\-]", "")
        End Function

        Public Sub Validate(row As Assignment, phones As HashSet(Of String), rowNumber As Integer)
            Dim prefix As String = "Row " & rowNumber.ToString(CultureInfo.InvariantCulture) & ": "
            If String.IsNullOrWhiteSpace(row.EmployeeNumber) OrElse row.EmployeeNumber.Length > 64 Then
                Throw New InputException(prefix & "employee number is required and must be at most 64 characters.")
            End If
            If String.IsNullOrWhiteSpace(row.MobileNumber) OrElse row.MobileNumber.Length > 64 OrElse
                Not Regex.IsMatch(row.MobileNumber, "^\+?[0-9 ()\-.]+$") OrElse
                Not Regex.IsMatch(PhoneKey(row.MobileNumber), "^[0-9]+$") Then
                Throw New InputException(prefix & "Mobile Number must contain a valid phone number, at most 64 characters.")
            End If
            If Not phones.Add(PhoneKey(row.MobileNumber)) Then
                Throw New InputException(prefix & "Mobile Number is duplicated in this file.")
            End If
            If Math.Abs(row.MonthlyCharge) > 999999999999999.9999D OrElse
                Decimal.Round(row.MonthlyCharge, 4) <> row.MonthlyCharge Then
                Throw New InputException(prefix & "monthly charge must fit 15 integer and 4 decimal digits.")
            End If
            If row.ActivationDate.HasValue AndAlso row.ActivationDate.Value.Year < 1753 Then
                Throw New InputException(prefix & "Activation Date is outside the supported date range.")
            End If
        End Sub
    End Module
End Namespace

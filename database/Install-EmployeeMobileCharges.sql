-- REVIEW ONLY until a DBA approves the target database. No USE CUS or MainInv.
-- Select the approved database in SSMS, then enable @Apply in a local copy.
-- SQL Server 2012+ is required for THROW. Never run on master/msdb/model/tempdb.
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Apply bit = 0;
IF @Apply = 0 OR DB_NAME() IN (N'master', N'msdb', N'model', N'tempdb') OR SCHEMA_ID(N'mobile') IS NOT NULL
BEGIN
    PRINT 'Not installing: confirm @Apply=1, an approved non-system database, and no existing mobile schema. Review before retrying.';
    SET NOEXEC ON;
END;
GO
CREATE SCHEMA mobile;
GO
CREATE TABLE mobile.Batch (
    BatchId uniqueidentifier NOT NULL PRIMARY KEY,
    BillingPeriod datetime NOT NULL,
    FileName nvarchar(200) NOT NULL,
    Publisher nvarchar(256) NOT NULL,
    PublishedAt datetime NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT CK_MobilePeriod CHECK (
        DAY(BillingPeriod)=1 AND BillingPeriod=DATEADD(day,DATEDIFF(day,0,BillingPeriod),0))
);
CREATE TABLE mobile.Assignment (
    BatchId uniqueidentifier NOT NULL REFERENCES mobile.Batch(BatchId),
    EmployeeNumber nvarchar(64) NOT NULL,
    Phone nvarchar(64) NOT NULL,
    PhoneKey nvarchar(64) NOT NULL,
    MonthlyCharge decimal(19,4) NOT NULL,
    ActivationDate datetime NULL,
    CONSTRAINT PK_MobileAssignment PRIMARY KEY (BatchId, PhoneKey)
);
CREATE INDEX IX_MobileEmployee ON mobile.Assignment(BatchId, EmployeeNumber);
CREATE TABLE mobile.CurrentSnapshot (
    Singleton int NOT NULL PRIMARY KEY CHECK (Singleton=1),
    BatchId uniqueidentifier NULL REFERENCES mobile.Batch(BatchId)
);
INSERT mobile.CurrentSnapshot(Singleton, BatchId) VALUES (1, NULL);
GO
CREATE PROCEDURE mobile.ReadEmployee
    @EmployeeNumber nvarchar(64)
AS
BEGIN
    SET NOCOUNT ON;
    -- Both result sets must refer to the same snapshot during a concurrent publish.
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @BatchId uniqueidentifier;
        SELECT @BatchId=BatchId FROM mobile.CurrentSnapshot WITH (HOLDLOCK) WHERE Singleton=1;
        SELECT BillingPeriod FROM mobile.Batch WHERE BatchId=@BatchId;
        SELECT Phone, MonthlyCharge, ActivationDate
        FROM mobile.Assignment
        WHERE BatchId=@BatchId AND EmployeeNumber=@EmployeeNumber
        ORDER BY Phone;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
CREATE PROCEDURE mobile.Publish
    @BatchId uniqueidentifier,
    @Period datetime,
    @FileName nvarchar(200),
    @Publisher nvarchar(256),
    @Rows xml
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Period IS NULL OR DAY(@Period)<>1 OR @Period<>DATEADD(day,DATEDIFF(day,0,@Period),0)
        THROW 50002, 'Invalid billing period.', 1;
    DECLARE @Count int = @Rows.value('count(/rows/row)', 'int');
    IF @Count IS NULL OR @Count<0 OR @Count>20000
        THROW 50002, 'Invalid assignment count.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @CurrentId uniqueidentifier, @CurrentPeriod datetime;
        SELECT @CurrentId=BatchId
        FROM mobile.CurrentSnapshot WITH (UPDLOCK,HOLDLOCK)
        WHERE Singleton=1;
        SELECT @CurrentPeriod=BillingPeriod FROM mobile.Batch WHERE BatchId=@CurrentId;
        IF @Period<@CurrentPeriod
            THROW 50001, 'An earlier period cannot replace the current publication.', 1;
        -- Repeated confirmation after a lost response must not duplicate a batch.
        IF @BatchId=@CurrentId
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END;
        INSERT mobile.Batch(BatchId,BillingPeriod,FileName,Publisher)
        VALUES (@BatchId,@Period,@FileName,@Publisher);
        INSERT mobile.Assignment(BatchId,EmployeeNumber,Phone,PhoneKey,MonthlyCharge,ActivationDate)
        SELECT @BatchId,
            item.value('@employee','nvarchar(64)'),
            item.value('@phone','nvarchar(64)'),
            item.value('@phoneKey','nvarchar(64)'),
            item.value('@charge','decimal(19,4)'),
            CASE WHEN item.exist('@activation')=1
                THEN CONVERT(datetime,item.value('@activation','nvarchar(10)'),126) ELSE NULL END
        FROM @Rows.nodes('/rows/row') AS source(item);
        IF EXISTS (SELECT 1 FROM mobile.Assignment WHERE BatchId=@BatchId AND
            (LEN(LTRIM(RTRIM(EmployeeNumber)))=0 OR LEN(Phone)=0 OR LEN(PhoneKey)=0))
            THROW 50002, 'An assignment is missing required identifiers.', 1;
        UPDATE mobile.CurrentSnapshot SET BatchId=@BatchId WHERE Singleton=1;
        -- Keep only the active snapshot; no employee-facing history is introduced.
        DELETE mobile.Assignment WHERE BatchId<>@BatchId;
        DELETE mobile.Batch WHERE BatchId<>@BatchId;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
-- DBA grants EXECUTE on mobile.ReadEmployee to the employee-view SQL principal.
-- Grant EXECUTE on mobile.Publish only to the independently configured upload
-- SQL principal. No db_owner, db_datareader or grants on legacy objects needed.
SET NOEXEC OFF;

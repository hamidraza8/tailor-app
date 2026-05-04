namespace TailorShop.Domain.Enums;

public enum UserRole
{
    Admin = 0,
    Partner = 1,
    Staff = 2
}

public enum ApprovalStatus
{
    PendingApproval = 0,
    Approved = 1,
    Rejected = 2
}

public enum SyncStatus
{
    Pending = 0,
    Synced = 1,
    Failed = 2,
    Conflict = 3
}

public enum OrderStatus
{
    Received = 0,
    Cutting = 1,
    Stitching = 2,
    Finishing = 3,
    Ready = 4,
    Delivered = 5,
    Cancelled = 6
}

public enum OrderType
{
    Suit = 0,
    Kurti = 1,
    Trouser = 2,
    Frock = 3,
    Abaya = 4,
    Alteration = 5,
    Other = 6
}

/// <summary>Legacy simple ownership field on Asset entity. Use AssetOwnershipType + AssetOwnership records for the new accounting module.</summary>
public enum LegacyAssetOwnership
{
    You = 0,
    Partner = 1,
    Company = 2
}

// ─── Accounting Module Enums ──────────────────────────────────────────────

public enum CapitalTransactionType
{
    CapitalAdvance = 0,
    AdditionalCapital = 1,
    Withdrawal = 2,
    Adjustment = 3
}

public enum SpendingCategory
{
    AssetPurchase = 0,
    InventoryPurchase = 1,
    Rent = 2,
    Utility = 3,
    Salary = 4,
    Labour = 5,
    Marketing = 6,
    Misc = 7
}

public enum SpendingResultType
{
    Asset = 0,
    Inventory = 1,
    Expense = 2
}

public enum AssetOwnershipType
{
    PartnerOwned = 0,
    CompanyOwned = 1,
    SplitOwned = 2
}

public enum AssetOwnerType
{
    Partner = 0,
    Company = 1
}

public enum PaymentMethod
{
    Cash = 0,
    BankTransfer = 1,
    EasyPaisa = 2,
    JazzCash = 3,
    Other = 4
}

public enum InventoryTransactionType
{
    Purchase = 0,
    UsedInOrder = 1,
    Adjustment = 2,
    Return = 3
}

public enum FileCategory
{
    AssetPhoto = 0,
    AssetReceipt = 1,
    InventoryPhoto = 2,
    InventoryReceipt = 3,
    OrderDesign = 4,
    OrderPhoto = 5,
    CustomerPhoto = 7,
    InvoicePdf = 8,
    OcrDocument = 9,
    VoiceNote = 10
}

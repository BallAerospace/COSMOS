/*
 * exchndl.c
 *
 * Author:
 *   Jose Fonseca <j_r_fonseca@yahoo.co.uk>
 *
 * Originally based on Matt Pietrek's MSJEXHND.CPP in Microsoft Systems
 * Journal, April 1997.
 *
 * Modified under terms of the LPGL and patched for COSMOS
 * The complete source code for drmingw 0.6.4 can be found here:
 * https://github.com/jrfonseca/drmingw/releases
 */

#include <assert.h>
#include <windows.h>
#include <tchar.h>
#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>

#include <dbghelp.h>

#include "pehelp.h"
#include "mgwhelp.h"
#include "symbols.h"


#define REPORT_FILE 1


// Declare the static variables
static LPTOP_LEVEL_EXCEPTION_FILTER prevExceptionFilter = NULL;
#if REPORT_FILE
static TCHAR szLogFileName[MAX_PATH] = _T("");
static HANDLE hReportFile;
#endif

static
#ifdef __GNUC__
    __attribute__ ((format (printf, 1, 2)))
#endif
int __cdecl rprintf(const TCHAR * format, ...)
{
#if REPORT_FILE
    TCHAR szBuff[4096];
    int retValue;
    DWORD cbWritten;
    va_list argptr;

    va_start(argptr, format);
    retValue = wvsprintf(szBuff, format, argptr);
    va_end(argptr);

    WriteFile(hReportFile, szBuff, retValue * sizeof(TCHAR), &cbWritten, 0);
    return retValue;
#else
    static char buf[4096] = {'\0'};
    // Buffer until a newline is found.
    size_t len = strlen(buf);
    va_list ap;
    va_start(ap, format);
    int ret = _vsnprintf(buf + len, sizeof(buf) - len, format, ap);
    va_end(ap);
    if (ret > (int)(sizeof(buf) - len - 1) || strchr(buf + len, '\n')) {
        OutputDebugStringA(buf);
        buf[0] = '\0';
    }
    return ret;
#endif
}

static BOOL
StackBackTrace(HANDLE hProcess, HANDLE hThread, PCONTEXT pContext)
{
    DWORD MachineType;
    STACKFRAME64 StackFrame;
    CONTEXT Context;

    HMODULE hModule = NULL;
    TCHAR szModule[MAX_PATH];

    assert(!bSymInitialized);

    DWORD dwSymOptions = SymGetOptions();
    dwSymOptions |=
        SYMOPT_LOAD_LINES |
        SYMOPT_DEFERRED_LOADS;
    SymSetOptions(dwSymOptions);
    if(SymInitialize(hProcess, "srv*C:\\Symbols*http://msdl.microsoft.com/download/symbols", TRUE))
        bSymInitialized = TRUE;

    memset( &StackFrame, 0, sizeof(StackFrame) );

    // Initialize the STACKFRAME structure for the first call.  This is only
    // necessary for Intel CPUs, and isn't mentioned in the documentation.
#if defined(_M_IX86)
    MachineType = IMAGE_FILE_MACHINE_I386;
    StackFrame.AddrPC.Offset = pContext->Eip;
    StackFrame.AddrPC.Mode = AddrModeFlat;
    StackFrame.AddrStack.Offset = pContext->Esp;
    StackFrame.AddrStack.Mode = AddrModeFlat;
    StackFrame.AddrFrame.Offset = pContext->Ebp;
    StackFrame.AddrFrame.Mode = AddrModeFlat;
#else
    MachineType = IMAGE_FILE_MACHINE_AMD64;
    StackFrame.AddrPC.Offset = pContext->Rip;
    StackFrame.AddrPC.Mode = AddrModeFlat;
    StackFrame.AddrStack.Offset = pContext->Rsp;
    StackFrame.AddrStack.Mode = AddrModeFlat;
    StackFrame.AddrFrame.Offset = pContext->Rbp;
    StackFrame.AddrFrame.Mode = AddrModeFlat;
#endif

    // StackWalk modifies context, so use a local copy.
    Context = *pContext;
    pContext = &Context;

    rprintf( _T("AddrPC   Params\r\n") );

    while ( 1 )
    {
        TCHAR szSymName[512] = _T("");
        TCHAR szFileName[MAX_PATH] = _T("");
        DWORD dwLineNumber = 0;

        if(!StackWalk64(
                MachineType,
                hProcess,
                hThread,
                &StackFrame,
                pContext,
                NULL,
                SymFunctionTableAccess64,
                GetModuleBase64,
                NULL
            )
        )
            break;

        // Basic sanity check to make sure  the frame is OK.  Bail if not.
        if ( 0 == StackFrame.AddrFrame.Offset )
            break;

#ifdef _M_IX86
        rprintf(
            _T("%08lX %08lX %08lX %08lX"),
            (DWORD)StackFrame.AddrPC.Offset,
            (DWORD)StackFrame.Params[0],
            (DWORD)StackFrame.Params[1],
            (DWORD)StackFrame.Params[2]
        );
#else
        rprintf(
            _T("%08I64X %08I64X %08I64X %08I64X"),
            StackFrame.AddrPC.Offset,
            StackFrame.Params[0],
            StackFrame.Params[1],
            StackFrame.Params[2]
        );
#endif

        if((hModule = (HMODULE)(INT_PTR)GetModuleBase64(hProcess, (DWORD64)(INT_PTR)StackFrame.AddrPC.Offset)) &&
           GetModuleFileName(hModule, szModule, sizeof(szModule)))
        {
            rprintf( _T("  %s"), GetBaseName(szModule));

            if (bSymInitialized &&
                GetSymFromAddr(hProcess, StackFrame.AddrPC.Offset, szSymName, 512))
            {
                rprintf( _T("!%s"), szSymName);

                UnDecorateSymbolName(szSymName, szSymName, 512, UNDNAME_COMPLETE);

                if(GetLineFromAddr(hProcess, StackFrame.AddrPC.Offset, szFileName, MAX_PATH, &dwLineNumber))
                    rprintf( _T("  [%s @ %ld]"), szFileName, dwLineNumber);
            } else {
                rprintf( _T("!%lx"), (DWORD)((INT_PTR)StackFrame.AddrPC.Offset - (INT_PTR)hModule));
            }
        }

        rprintf(_T("\r\n"));
    }

    if(bSymInitialized)
    {
        if(!SymCleanup(hProcess))
            assert(0);

        bSymInitialized = FALSE;
    }

    return TRUE;
}

extern void rb_vm_bugreport(void);

static
void GenerateExceptionReport(PEXCEPTION_POINTERS pExceptionInfo)
{
    PEXCEPTION_RECORD pExceptionRecord = pExceptionInfo->ExceptionRecord;
    TCHAR szModule[MAX_PATH];
    HMODULE hModule;
    PCONTEXT pContext;
    HANDLE hProcess = GetCurrentProcess();

    // Start out with a banner
    rprintf(_T("-------------------\r\n\r\n"));

    {
        TCHAR *lpDayOfWeek[] = {
            _T("Sunday"),
            _T("Monday"),
            _T("Tuesday"),
            _T("Wednesday"),
            _T("Thursday"),
            _T("Friday"),
            _T("Saturday")
        };
        TCHAR *lpMonth[] = {
            NULL,
            _T("January"),
            _T("February"),
            _T("March"),
            _T("April"),
            _T("May"),
            _T("June"),
            _T("July"),
            _T("August"),
            _T("September"),
            _T("October"),
            _T("November"),
            _T("December")
        };
        SYSTEMTIME SystemTime;

        GetLocalTime(&SystemTime);
        rprintf(_T("Error occured on %s, %s %i, %i at %02i:%02i:%02i.\r\n\r\n"),
            lpDayOfWeek[SystemTime.wDayOfWeek],
            lpMonth[SystemTime.wMonth],
            SystemTime.wDay,
            SystemTime.wYear,
            SystemTime.wHour,
            SystemTime.wMinute,
            SystemTime.wSecond
        );
    }

    // First print information about the type of fault
    rprintf(_T("%s caused "),  GetModuleFileName(NULL, szModule, MAX_PATH) ? szModule : "Application");
    switch(pExceptionRecord->ExceptionCode)
    {
        case EXCEPTION_ACCESS_VIOLATION:
            rprintf(_T("an Access Violation"));
            break;

        case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:
            rprintf(_T("an Array Bound Exceeded"));
            break;

        case EXCEPTION_BREAKPOINT:
            rprintf(_T("a Breakpoint"));
            break;

        case EXCEPTION_DATATYPE_MISALIGNMENT:
            rprintf(_T("a Datatype Misalignment"));
            break;

        case EXCEPTION_FLT_DENORMAL_OPERAND:
            rprintf(_T("a Float Denormal Operand"));
            break;

        case EXCEPTION_FLT_DIVIDE_BY_ZERO:
            rprintf(_T("a Float Divide By Zero"));
            break;

        case EXCEPTION_FLT_INEXACT_RESULT:
            rprintf(_T("a Float Inexact Result"));
            break;

        case EXCEPTION_FLT_INVALID_OPERATION:
            rprintf(_T("a Float Invalid Operation"));
            break;

        case EXCEPTION_FLT_OVERFLOW:
            rprintf(_T("a Float Overflow"));
            break;

        case EXCEPTION_FLT_STACK_CHECK:
            rprintf(_T("a Float Stack Check"));
            break;

        case EXCEPTION_FLT_UNDERFLOW:
            rprintf(_T("a Float Underflow"));
            break;

        case EXCEPTION_GUARD_PAGE:
            rprintf(_T("a Guard Page"));
            break;

        case EXCEPTION_ILLEGAL_INSTRUCTION:
            rprintf(_T("an Illegal Instruction"));
            break;

        case EXCEPTION_IN_PAGE_ERROR:
            rprintf(_T("an In Page Error"));
            break;

        case EXCEPTION_INT_DIVIDE_BY_ZERO:
            rprintf(_T("an Integer Divide By Zero"));
            break;

        case EXCEPTION_INT_OVERFLOW:
            rprintf(_T("an Integer Overflow"));
            break;

        case EXCEPTION_INVALID_DISPOSITION:
            rprintf(_T("an Invalid Disposition"));
            break;

        case EXCEPTION_INVALID_HANDLE:
            rprintf(_T("an Invalid Handle"));
            break;

        case EXCEPTION_NONCONTINUABLE_EXCEPTION:
            rprintf(_T("a Noncontinuable Exception"));
            break;

        case EXCEPTION_PRIV_INSTRUCTION:
            rprintf(_T("a Privileged Instruction"));
            break;

        case EXCEPTION_SINGLE_STEP:
            rprintf(_T("a Single Step"));
            break;

        case EXCEPTION_STACK_OVERFLOW:
            rprintf(_T("a Stack Overflow"));
            break;

        case DBG_CONTROL_C:
            rprintf(_T("a Control+C"));
            break;

        case DBG_CONTROL_BREAK:
            rprintf(_T("a Control+Break"));
            break;

        case DBG_TERMINATE_THREAD:
            rprintf(_T("a Terminate Thread"));
            break;

        case DBG_TERMINATE_PROCESS:
            rprintf(_T("a Terminate Process"));
            break;

        case RPC_S_UNKNOWN_IF:
            rprintf(_T("an Unknown Interface"));
            break;

        case RPC_S_SERVER_UNAVAILABLE:
            rprintf(_T("a Server Unavailable"));
            break;

        default:
            /*
            static TCHAR szBuffer[512] = { 0 };

            // If not one of the "known" exceptions, try to get the string
            // from NTDLL.DLL's message table.

            FormatMessage(FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_FROM_HMODULE,
                            GetModuleHandle(_T("NTDLL.DLL")),
                            dwCode, 0, szBuffer, sizeof(szBuffer), 0);
            */

            rprintf(_T("an Unknown [0x%lX] Exception"), pExceptionRecord->ExceptionCode);
            break;
    }

    // Now print information about where the fault occured
    rprintf(_T(" at location %p"), pExceptionRecord->ExceptionAddress);
    if((hModule = (HMODULE)(INT_PTR)GetModuleBase64(hProcess, (DWORD64)(INT_PTR)pExceptionRecord->ExceptionAddress)) &&
       GetModuleFileName(hModule, szModule, sizeof szModule))
        rprintf(_T(" in module %s"), szModule);

    // If the exception was an access violation, print out some additional information, to the error log and the debugger.
    if(pExceptionRecord->ExceptionCode == EXCEPTION_ACCESS_VIOLATION &&
       pExceptionRecord->NumberParameters >= 2)
        rprintf(" %s location %p",
            pExceptionRecord->ExceptionInformation[0] ? "Writing to" : "Reading from",
            (LPCVOID)pExceptionRecord->ExceptionInformation[1]);

    rprintf(".\r\n\r\n");

    CloseHandle(hReportFile);
    freopen(szLogFileName, "a", stderr);
    rb_vm_bugreport();
    fflush(stderr);
    freopen("CON", "w", stderr);
    hReportFile = CreateFile(
        szLogFileName,
        GENERIC_WRITE,
        0,
        0,
        OPEN_ALWAYS,
        FILE_FLAG_WRITE_THROUGH,
        0
    );
    SetFilePointer(hReportFile, 0, 0, FILE_END);


    pContext = pExceptionInfo->ContextRecord;

    #ifdef _M_IX86    // Intel Only!

    // Show the registers
    rprintf(_T("Registers:\r\n"));
    if(pContext->ContextFlags & CONTEXT_INTEGER)
        rprintf(
            _T("eax=%08lx ebx=%08lx ecx=%08lx edx=%08lx esi=%08lx edi=%08lx\r\n"),
            pContext->Eax,
            pContext->Ebx,
            pContext->Ecx,
            pContext->Edx,
            pContext->Esi,
            pContext->Edi
        );
    if(pContext->ContextFlags & CONTEXT_CONTROL)
        rprintf(
            _T("eip=%08lx esp=%08lx ebp=%08lx iopl=%1lx %s %s %s %s %s %s %s %s %s %s\r\n"),
            pContext->Eip,
            pContext->Esp,
            pContext->Ebp,
            (pContext->EFlags >> 12) & 3,    //  IOPL level value
            pContext->EFlags & 0x00100000 ? "vip" : "   ",    //  VIP (virtual interrupt pending)
            pContext->EFlags & 0x00080000 ? "vif" : "   ",    //  VIF (virtual interrupt flag)
            pContext->EFlags & 0x00000800 ? "ov" : "nv",    //  VIF (virtual interrupt flag)
            pContext->EFlags & 0x00000400 ? "dn" : "up",    //  OF (overflow flag)
            pContext->EFlags & 0x00000200 ? "ei" : "di",    //  IF (interrupt enable flag)
            pContext->EFlags & 0x00000080 ? "ng" : "pl",    //  SF (sign flag)
            pContext->EFlags & 0x00000040 ? "zr" : "nz",    //  ZF (zero flag)
            pContext->EFlags & 0x00000010 ? "ac" : "na",    //  AF (aux carry flag)
            pContext->EFlags & 0x00000004 ? "po" : "pe",    //  PF (parity flag)
            pContext->EFlags & 0x00000001 ? "cy" : "nc"    //  CF (carry flag)
        );
    if(pContext->ContextFlags & CONTEXT_SEGMENTS)
    {
        rprintf(
            _T("cs=%04lx  ss=%04lx  ds=%04lx  es=%04lx  fs=%04lx  gs=%04lx"),
            pContext->SegCs,
            pContext->SegSs,
            pContext->SegDs,
            pContext->SegEs,
            pContext->SegFs,
            pContext->SegGs
        );
        if(pContext->ContextFlags & CONTEXT_CONTROL)
            rprintf(
                _T("             efl=%08lx"),
                pContext->EFlags
            );
    }
    else
        if(pContext->ContextFlags & CONTEXT_CONTROL)
            rprintf(
                _T("                                                                       efl=%08lx"),
                pContext->EFlags
            );
    rprintf(_T("\r\n\r\n"));

    #endif

    StackBackTrace(hProcess, GetCurrentThread(), pContext);

    rprintf(_T("\r\n\r\n"));
}

#include <stdio.h>
#include <fcntl.h>
#include <io.h>


// Entry point where control comes on an unhandled exception
static
LONG CALLBACK TopLevelExceptionFilter(PEXCEPTION_POINTERS pExceptionInfo)
{
    char *cosmos_log_dir = NULL;
    PEXCEPTION_RECORD pExceptionRecord = pExceptionInfo->ExceptionRecord;

    /*
     * Ignore OutputDebugStringA exception.
     */
    if (   ((unsigned long)pExceptionRecord->ExceptionCode < 0x80000000UL) ||
           ((unsigned long)pExceptionRecord->ExceptionCode == 0x80010108UL)) {
        return EXCEPTION_CONTINUE_SEARCH;
    }

    static BOOL bBeenHere = FALSE;

    if(!bBeenHere)
    {
        UINT fuOldErrorMode;

        bBeenHere = TRUE;

        fuOldErrorMode = SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);

        cosmos_log_dir = getenv("COSMOS_LOGS_DIR");
        if (cosmos_log_dir) {
          SYSTEMTIME SystemTime;

          GetLocalTime(&SystemTime);
          sprintf(szLogFileName,
            "%s\\%04u_%02u_%02u_%02u_%02u_%02u_segfault.txt",
            cosmos_log_dir,
            SystemTime.wYear,
            SystemTime.wMonth,
            SystemTime.wDay,
            SystemTime.wHour,
            SystemTime.wMinute,
            SystemTime.wSecond);
        }
#if REPORT_FILE
        hReportFile = CreateFile(
            szLogFileName,
            GENERIC_WRITE,
            0,
            0,
            OPEN_ALWAYS,
            FILE_FLAG_WRITE_THROUGH,
            0
        );

        if (hReportFile)
        {
            SetFilePointer(hReportFile, 0, 0, FILE_END);

            GenerateExceptionReport(pExceptionInfo);

            CloseHandle(hReportFile);
            hReportFile = 0;
        }
#else
        GenerateExceptionReport(pExceptionInfo);
#endif

        SetErrorMode(fuOldErrorMode);
    }

    return EXCEPTION_CONTINUE_SEARCH;
}

static void OnStartup(void)
{
    // Install the unhandled exception filter function
    prevExceptionFilter = AddVectoredExceptionHandler(0, TopLevelExceptionFilter);

#if REPORT_FILE
    // Figure out what the report file will be named, and store it away
    if(GetModuleFileName(NULL, szLogFileName, MAX_PATH))
    {
        LPTSTR lpszDot;

        // Look for the '.' before the "EXE" extension.  Replace the extension
        // with "RPT"
        if((lpszDot = _tcsrchr(szLogFileName, _T('.'))))
        {
            lpszDot++;    // Advance past the '.'
            _tcscpy(lpszDot, _T("RPT"));    // "RPT" -> "Report"
        }
        else
            _tcscat(szLogFileName, _T(".RPT"));
    }
    else if(GetWindowsDirectory(szLogFileName, MAX_PATH))
    {
        _tcscat(szLogFileName, _T("EXCHNDL.RPT"));
    }
#endif
}

static void OnExit(void)
{
    RemoveVectoredExceptionHandler(prevExceptionFilter);
}

BOOL APIENTRY DllMain(HINSTANCE hInstance, DWORD dwReason, LPVOID lpReserved);

BOOL APIENTRY DllMain(HINSTANCE hInstance, DWORD dwReason, LPVOID lpReserved)
{
    switch (dwReason)
    {
        case DLL_PROCESS_ATTACH:
            OnStartup();
            break;

        case DLL_PROCESS_DETACH:
            OnExit();
            break;
    }

    return TRUE;
}

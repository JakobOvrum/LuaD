set $_exitcode = -999

set height 0
set pagination 0
set disassembly-flavor intel

handle SIGTERM nostop print pass
handle SIGPIPE nostop

define hook-stop
    if $_exitcode == -999
        echo \n:::::::::: ACTIVE BACKTRACE :::::::::::\n\n
        backtrace full
        echo \n:::::::::: FUNCTION ARGUMENTS :::::::::\n\n
        info args
        echo \n:::::::::: LOCAL VARIABLES ::::::::::::\n\n
        info locals
        echo \n:::::::::: REGISTER INFO ::::::::::::::\n\n
        info all-registers
        echo \n:::::::::: FPU STATUS :::::::::::::::::\n\n
        info float
        echo \n:::::::::: RAW DISASSEMBLY ::::::::::::\n\n
        disassemble $pc-50,+100
        echo \n:::::::::: THREAD BACKTRACES ::::::::::\n
        thread apply all backtrace full
    end
    quit
end

run

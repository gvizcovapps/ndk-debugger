{BufferedProcess, Emitter} = require 'atom'
{RESULT, parser} = require '../backend/gdb/gdb-mi-parser'
GDB = require '../backend/gdb/gdb'
fs = require 'fs'

module.exports =
  class NdkGdb extends GDB

    STATUS =
      NOTHING: 0
      RUNNING: 1
      ERROR: 2

    constructor: (targetProject) ->
      @breakPoints = []
      @token = 0
      @handler = {}
      @emitter = new Emitter
      @stdoutMessage = "";

      stdout = (lines) =>
        console.log(lines)
        shouldParse = false
        allLinesInALine = ""
        for line in lines.split('\n')
          allLinesInALine += line
          switch line[0]
            when '+' then null  # status-async-output
            when '=' then null  # notify-async-output
            when '~' then null  # console-stream-output
            when '@' then null  # target-stream-output
            when '&' then null  # log-stream-output
            when '*'            # exec-async-output
              {clazz, result} = parser.parse(line)
              console.log("Result :",result)
              @emitter.emit 'exec-async-output', {clazz, result}
              @emitter.emit "exec-async-running", result if clazz == RESULT.RUNNING
              @emitter.emit "exec-async-stopped", result if clazz == RESULT.STOPPED
            else                # result-record
              if line[0] <= '9' and line[0] >= '0'
                {token,error,clazz, result,msg} = parser.parse(line)
                if error == false
                  @handler[token](clazz, result)
                  delete @handler[token]
                else
                  alert msg
              else
                if line.substr(0,5) == 'ERROR'
                  shouldParse = true

        # if shouldParse
        #    {error,msg} = parser.parse(allLinesInALine)
        #    if error
        #      atom.confirm
        #        detailedMessage: "Oops!!!  #{msg}"
        #        buttons:
        #          Exit: => @destroy()

      stderr = (lines) =>
        @errorMessage = lines

      command = '/Users/rpandian/Library/Android/ndk/android-ndk-r10d//ndk-gdb-atom'
      args = ["--adb=/Users/rpandian/Library/Android/sdk/platform-tools//adb","--project=#{targetProject}"] #
      console.log("arg", "--project=#{targetProject}")
      @process = new BufferedProcess({command, args, stdout, stderr}).process
      @stdin = @process.stdin
      @status = STATUS.NOTHING

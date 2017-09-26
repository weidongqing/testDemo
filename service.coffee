do ->
  angular.module 'app.service'
    .factory 'service', [
      '$uibModal'
      '$timeout'
      ($uibModal,$timeout) ->

        showMessageBox = (info, confirmCallback, cancelCallback) ->
          params =
            controller: 'messageBoxController'
            templateUrl: 'view/dialog/messagebox.html'
            resolve: data: ->
              return info
          if info and info.static is true
            params.backdrop = 'static'
          if info and info.keyboard is false
            params.keyboard = false
          console.log params
          dialog = $uibModal.open params
          dismiss = dialog.dismiss
          dialog.close = (result) ->
            confirmCallback result if confirmCallback
            dismiss()
            return
          dialog.dismiss = (result) ->
            cancelCallback result if cancelCallback
            dismiss()
            return
          return

        # show common notification
        showNotification = (title, content) ->
          notification = new Notification title,
            icon: "res/img/logo.png"
            body: content
          notification.onshow = ->
            $timeout ->
              notification.close()
            , 3000

        reportBug = ->
          $uibModal.open
            templateUrl: 'view/dialog/reportBug.html'
            controller: 'reportBugController'
            backdrop: 'static'
          return
          # userMail = 'none@forensix.cn'
          # fs = require 'fs'
          # path = require 'path'
          # exepath = path.dirname(process.execPath)
          # # exepath = if global.devMode then 'C:\\Program Files\\Honglian\\GoldenEyes' else path.dirname(process.execPath)
          # exec = require('child_process').exec
          # if global.isWindows
          #   bugReportFile = '"' + exepath + '\\bugreport.exe" --email='+userMail + ' --version=' +nw.App.manifest.version
          # else
          #   bugReportFile = '"' + exepath + '/bugreport.exe" --email='+userMail + ' --version=' +nw.App.manifest.version
          # bugReport = exec bugReportFile, (err, stdout, stderr) ->
          #   if err
          #     info =
          #       title: '反馈问题'
          #       message: '上传软件日志失败！'
          #       noFoot: true
          #     info.message += err
          #     showMessageBox info
          #     return
          #   ret = JSON.parse stdout
          #   message = ''
          #   if ret.result or ret.Result
          #     message = '上传软件日志成功！'
          #   else if ret.Error
          #     message = '上传软件日志失败！' + ret.Error
          #   else
          #     message = '上传软件日志未知错误！' + stdout
          #   info =
          #     title: '反馈问题'
          #     message: message
          #     noFoot: true
          #   showMessageBox info
          #   return
          # return

        # get localStorage
        getLocalStorage = (key, cb) ->
          return cb null, localStorage[key] if not localStorage[key]
          try
            value = JSON.parse localStorage[key]
          catch err
            return cb err
          return cb null, value

        # save localStorage
        setLocalStorage = (key, value) ->
          localStorage[key] = JSON.stringify value
          return

        openHelp = ->
          fs = require 'fs'
          path = require 'path'
          if global.isWindows
            filepath = path.dirname(process.execPath) + '\\manual.pdf'
          else
            filepath = path.dirname(process.execPath) + '/manual.pdf'
          fs.stat filepath, (err, stats) ->
            if err
              console.log 'error', err.message if err.message
              return
            if stats.isFile()
              nw.Shell.openItem filepath
            return
          return

        # get not inuse local port
        checkPort = (host, port, cb) ->
          net = require 'net'
          cleanUp = ->
            if client
              client.removeAllListeners 'connect'
              client.removeAllListeners 'error'
              client.end()
              client.destroy()
              client.unref()
            return
          client = new net.Socket()
          client.once 'connect', ->
            cb null, true
            cleanUp()
          client.once 'error', (err) ->
            if err.code != 'ECONNREFUSED'
              cb err
            else
              cb null, false
            cleanUp()
            return
          client.connect
            host: host
            port: port
          return

        # launch master server for desktop app
        startMaster = (cb) ->
          port = 8000 + ~~(Math.random()*1000)
          checkPort '127.0.0.1', port, (err, inUse) ->
            if err
              console.log 'startMaster error', err
              return cb err
            if inUse
              return cb new error 'port inUse'
            global.masterPort = port
            global.masterHost = 'http://127.0.0.1:' + port
            if not global.eventEmitter
              EventEmitter = require 'events'
              global.eventEmitter = new EventEmitter()
            global.eventEmitter.emit 'change:masterPort'
            global.eventEmitter.emit 'change:masterHost'
            fs = require 'fs'
            path = require 'path'
            exepath = path.dirname(process.execPath)
            spawn = require('child_process').spawn
            if global.devMode
              masterFile = 'C:\\Program Files\\Honglian\\GoldenEyes\\master.exe'
              console.log 'in dev mode ...', masterFile, port
              master = spawn masterFile, ['--port='+port]
              master.stdout.on 'data', (data) ->
                #console.log '>:' + data
                return
              master.stderr.on 'data', (data) ->
                console.log '>:ERROR:' + data
                return
              master.on 'close', (code) ->
                console.log 'master exited with code:', code
                info =
                  title: '提示'
                  message: '与master断开连接！'
                  noCancel: true
                showMessageBox info
                reportBug()
                return
              master.on 'error', (err) ->
                console.log 'Failed to start master process!' + err
                return
            else
              if global.isWindows
                master = spawn exepath + '\\master.exe', ['--port='+port]
              else
                master = spawn exepath + '/master.exe', ['--port='+port]
              master.on 'error', (err) ->
                info =
                  title: '错误'
                  message: '启动通讯服务失败！'
                  noCancel: true
                info.message += err if err
                showMessageBox info
                return
              if global.isWindows
                if fs.existsSync exepath + '\\log'
                  master.stdout.on 'data', (data) ->
                    fs.appendFile exepath + '\\log\\master.log', new Date() + ':' + data
                    return
                  master.stderr.on 'data', (data) ->
                    fs.appendFile exepath + '\\log\\master.error', new Date() + ':' + data
                    return
              else
                if fs.existsSync exepath + '/log'
                  master.stdout.on 'data', (data) ->
                    fs.appendFile exepath + '/log/master.log', new Date() + ':' + data
                    return
                  master.stderr.on 'data', (data) ->
                    fs.appendFile exepath + '/log/master.error', new Date() + ':' + data
                    return
            cb null
          return


        return {
          showMessageBox: showMessageBox
          getLocalStorage: getLocalStorage
          setLocalStorage: setLocalStorage
          startMaster: startMaster
          showNotification: showNotification
          openHelp: openHelp
          reportBug: reportBug
        }
    ]
  return

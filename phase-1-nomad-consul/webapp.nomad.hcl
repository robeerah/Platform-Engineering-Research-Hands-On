job "my-webapp" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count          = 1
    shutdown_delay = "5s"

    network {
      port "http" {}
    }

    service {
      name     = "my-webapp"
      port     = "http"
      provider = "consul"
      tags     = ["metrics", "platform-managed"]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "server" {
      driver = "raw_exec"

      config {
        command = "powershell.exe"
        args    = [
          "-NoProfile", "-ExecutionPolicy", "Bypass",
          "-Command",
          "$port = [int]$env:NOMAD_PORT_http; $msg = [Text.Encoding]::UTF8.GetBytes('Hello from Platform Engineering!'); $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::IPv6Any, $port); $l.Server.DualMode = $true; $l.Start(); $n = 0; Write-Host \"Server started on port $port\"; while ($true) { try { $c = $l.AcceptTcpClient(); $c.ReceiveTimeout = 2000; $s = $c.GetStream(); $r = New-Object System.IO.StreamReader($s); $req = $r.ReadLine(); $line = $req; while (-not [string]::IsNullOrEmpty($line)) { $line = $r.ReadLine() }; $n++; $path = \"$req\".Split(' ')[1]; if ($path -eq '/metrics') { $body = [Text.Encoding]::UTF8.GetBytes(\"app_requests_total{app=`\"my-webapp`\"} $n`napp_up{app=`\"my-webapp`\"} 1`n\"); $ct = 'text/plain; version=0.0.4' } else { $body = $msg; $ct = 'text/plain; charset=utf-8' }; $h = [Text.Encoding]::ASCII.GetBytes(\"HTTP/1.1 200 OK`r`nContent-Type: $ct`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n\"); $s.Write($h, 0, $h.Length); $s.Write($body, 0, $body.Length); $s.Flush(); $c.Close() } catch { Write-Host \"request error: $_\" } }"
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}

// kb-ota-ble — envia um firmware ao Adafruit nRF52 Bootloader por Bluetooth (Nordic Legacy DFU),
// usando só o CoreBluetooth do macOS. Chamado pelo `kb-ota send`; não use direto.
//
//   kb-ota-ble <application.bin> <application.dat> [segundos de busca]
//
// Protocolo (Adafruit_nRF52_Bootloader, lib/sdk11/.../ble_dfu.c e dfu_transport_ble.c):
//   serviço 00001530-1212-EFDE-1523-785FEABCD123 · ponto de controle …1531 (write + notify)
//   pacotes …1532 (write without response) · o bootloader anuncia "AdaDFU", sem pareamento
//   1 START [0x01,0x04] + tamanhos (sd, bl, app: 3×u32 LE) no …1532 → resposta [0x10,0x01,0x01]
//   2 INIT  [0x02,0x00] + init packet no …1532 + [0x02,0x01]      → resposta [0x10,0x02,0x01]
//   3 PRN   [0x08, N u16]   (confirmação [0x11, bytes u32] a cada N pacotes; N ≤ 8)
//   falha → só desconectar. NUNCA [0x06] SYS_RESET: ele reinicia sem a marca de OTA e, sem app válido,
//   o nice!nano volta no modo USB (sem DEFAULT_TO_OTA_DFU). Desconectado, o bootloader descarta a
//   transferência após 6 min sem atividade (DFU_TIMEOUT_INTERVAL 360000) e reinicia de volta em OTA.
//   4 FW    [0x03] + imagem em pacotes de 20 bytes                 → resposta [0x10,0x03,0x01]
//   5 VALIDATE [0x04] (o bootloader confere o CRC16)               → resposta [0x10,0x04,0x01]
//   6 ACTIVATE [0x05] → o bootloader grava e reinicia no firmware novo
import CoreBluetooth
import Foundation

let base = "-1212-EFDE-1523-785FEABCD123"
let svcUUID = CBUUID(string: "00001530" + base)
let ctrlUUID = CBUUID(string: "00001531" + base)
let pktUUID = CBUUID(string: "00001532" + base)

let packetSize = 20  // múltiplo de 4 (o bootloader grava a flash em palavras de 32 bits)
// confirmação a cada 4 pacotes: a fila de recebimento do bootloader por BLE tem 8 posições
// (hci_mem_pool_internal.h: RX_BUF_QUEUE_SIZE 8u) e a confirmação sai quando o pacote CHEGA,
// não quando é gravado; com 10 a fila estourava ("operação falhou" no passo 3).
let prn: UInt16 = 4

func log(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }
func fail(_ s: String) -> Never { log("kb-ota: " + s); exit(1) }

let args = CommandLine.arguments
guard args.count >= 3 else { fail("uso: kb-ota-ble <application.bin> <application.dat> [segundos de busca]") }
guard let image = FileManager.default.contents(atPath: args[1]) else { fail("não consegui ler \(args[1])") }
guard let initPacket = FileManager.default.contents(atPath: args[2]) else { fail("não consegui ler \(args[2])") }
let scanTimeout = args.count > 3 ? (Double(args[3]) ?? 90) : 90

func u32(_ v: UInt32) -> [UInt8] { [UInt8(v & 0xff), UInt8((v >> 8) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 24) & 0xff)] }

let statusText: [UInt8: String] = [
    2: "estado inválido", 3: "operação não suportada", 4: "tamanho de dados acima do limite",
    5: "CRC não confere (pacote corrompido na transferência)", 6: "operação falhou",
]

final class DFU: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    enum Step { case scanning, connecting, waitStart, waitInit, sending, waitReceived, waitValidate, activating, waitingTimeout }
    var central: CBCentralManager!
    var peripheral: CBPeripheral?
    var ctrl: CBCharacteristic?
    var pkt: CBCharacteristic?
    var step = Step.scanning
    var offset = 0
    var sinceReceipt = 0
    var lastPercent = -5
    var attempt = 1
    var started = Date()
    let image: Data
    let initPacket: Data
    let scanTimeout: Double

    init(image: Data, initPacket: Data, scanTimeout: Double) {
        self.image = image
        self.initPacket = initPacket
        self.scanTimeout = scanTimeout
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        switch c.state {
        case .poweredOn:
            log("procurando o teclado em modo OTA (\"AdaDFU\")… aperte Func + OTA na metade que vai atualizar")
            c.scanForPeripherals(withServices: nil, options: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + self.scanTimeout) {
                if self.step == .scanning { fail("nenhum dispositivo em modo OTA em \(Int(self.scanTimeout)) s") }
            }
        case .unauthorized:
            fail("sem permissão de Bluetooth: Ajustes do Sistema → Privacidade e Segurança → Bluetooth → libere o terminal (Ghostty)")
        case .poweredOff: fail("o Bluetooth do Mac está desligado")
        case .unsupported: fail("Bluetooth indisponível neste Mac")
        default: break
        }
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData ad: [String: Any], rssi: NSNumber) {
        let name = (ad[CBAdvertisementDataLocalNameKey] as? String) ?? p.name ?? ""
        let services = (ad[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        guard step == .scanning, name == "AdaDFU" || services.contains(svcUUID) else { return }
        log("achei \"\(name.isEmpty ? "sem nome" : name)\" (RSSI \(rssi)); conectando…")
        step = .connecting
        peripheral = p
        c.stopScan()
        p.delegate = self
        c.connect(p, options: nil)
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) { p.discoverServices([svcUUID]) }
    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        fail("não conectou: \(error?.localizedDescription ?? "?")")
    }
    func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        if step == .activating {
            log(String(format: "pronto: firmware gravado em %.0f s; a metade reiniciou com a versão nova", Date().timeIntervalSince(started)))
            exit(0)
        }
        if step == .waitingTimeout { return }
        fail("a conexão caiu no meio (\(step)); a metade fica no bootloader: rode de novo ou use o cabo")
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let s = p.services?.first(where: { $0.uuid == svcUUID }) else { fail("serviço DFU não encontrado") }
        p.discoverCharacteristics([ctrlUUID, pktUUID], for: s)
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        ctrl = s.characteristics?.first { $0.uuid == ctrlUUID }
        pkt = s.characteristics?.first { $0.uuid == pktUUID }
        guard let ctrl, pkt != nil else { fail("características DFU não encontradas") }
        p.setNotifyValue(true, for: ctrl)
    }

    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor ch: CBCharacteristic, error: Error?) {
        if let error { fail("não consegui ativar as notificações: \(error.localizedDescription)") }
        guard ch.uuid == ctrlUUID, step == .connecting else { return }
        started = Date()
        log("iniciando: \(image.count) bytes")
        step = .waitStart
        writeCtrl([0x01, 0x04])  // START_DFU, tipo aplicação
        writePkt(Data(u32(0) + u32(0) + u32(UInt32(image.count))))  // tamanhos: SoftDevice, bootloader, aplicação
    }

    func peripheral(_ p: CBPeripheral, didWriteValueFor ch: CBCharacteristic, error: Error?) {
        if let error { fail("escrita recusada no ponto de controle: \(error.localizedDescription)") }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard ch.uuid == ctrlUUID, let v = ch.value, !v.isEmpty else { return }
        let b = [UInt8](v)
        if b[0] == 0x11 {  // confirmação de recebimento
            sinceReceipt = 0
            sendPackets()
            return
        }
        guard b[0] == 0x10, b.count >= 3 else { return }
        let (op, status) = (b[1], b[2])
        if op == 0x01 && status == 2 && attempt == 1 {
            // transferência anterior pela metade: reinicia o bootloader e tenta de novo
            attempt += 1
            waitBootloaderTimeout()
            return
        }
        guard status == 1 else { abort("o bootloader respondeu erro no passo \(op): \(statusText[status] ?? "código \(status)")") }
        switch (op, step) {
        case (0x01, .waitStart):
            step = .waitInit
            writeCtrl([0x02, 0x00])
            var i = 0
            while i < initPacket.count {
                writePkt(initPacket.subdata(in: i..<min(i + packetSize, initPacket.count)))
                i += packetSize
            }
            writeCtrl([0x02, 0x01])
        case (0x02, .waitInit):
            writeCtrl([0x08, UInt8(prn & 0xff), UInt8(prn >> 8)])
            writeCtrl([0x03])
            step = .sending
            sendPackets()
        case (0x03, .waitReceived):
            log("firmware recebido; validando o CRC…")
            step = .waitValidate
            writeCtrl([0x04])
        case (0x04, .waitValidate):
            log("validado; ativando e reiniciando…")
            step = .activating
            writeCtrl([0x05])
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                log("pronto: o bootloader confirmou o firmware e foi reiniciar")
                exit(0)
            }
        default: break
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse p: CBPeripheral) { sendPackets() }

    func sendPackets() {
        guard step == .sending, let p = peripheral, let pkt else { return }
        while offset < image.count && sinceReceipt < Int(prn) {
            guard p.canSendWriteWithoutResponse else { return }  // retoma em peripheralIsReady
            let end = min(offset + packetSize, image.count)
            p.writeValue(image.subdata(in: offset..<end), for: pkt, type: .withoutResponse)
            offset = end
            sinceReceipt += 1
            let pct = offset * 100 / image.count
            if pct / 5 != lastPercent / 5 {
                lastPercent = pct
                log(String(format: "  %3d%%  %6d/%d bytes  %.0f s", pct, offset, image.count, Date().timeIntervalSince(started)))
            }
        }
        if offset >= image.count { step = .waitReceived }
    }

    /// Falha depois de conectado: só desconecta (ver o cabeçalho: SYS_RESET derrubaria o modo OTA).
    func abort(_ msg: String) -> Never {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        fail(msg + "\n  o bootloader descarta essa transferência sozinho após 6 min sem atividade e volta ao modo OTA;"
            + "\n  rode `kb-ota send` de novo depois disso (ou na hora: ele espera e repete sozinho)")
    }

    /// "Estado inválido" no início: desconecta, espera o bootloader zerar (6 min) e procura de novo.
    func waitBootloaderTimeout() {
        step = .waitingTimeout
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        offset = 0; sinceReceipt = 0; lastPercent = -5
        ctrl = nil; pkt = nil; peripheral = nil
        let wait = 390
        log("o bootloader está com uma transferência anterior pela metade; ele a descarta após 6 min sem atividade.")
        for m in stride(from: 60, to: wait, by: 60) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(m)) { log("  aguardando… \((wait - m) / 60 + 1) min") }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(wait)) {
            self.step = .scanning
            log("procurando de novo…")
            self.central.scanForPeripherals(withServices: nil, options: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 120) {
                if self.step == .scanning { fail("o bootloader não voltou a anunciar; aperte o reset da metade duas vezes e use o cabo") }
            }
        }
    }

    func writeCtrl(_ bytes: [UInt8]) { peripheral?.writeValue(Data(bytes), for: ctrl!, type: .withResponse) }
    func writePkt(_ data: Data) { peripheral?.writeValue(data, for: pkt!, type: .withoutResponse) }
}

let dfu = DFU(image: image, initPacket: initPacket, scanTimeout: scanTimeout)
signal(SIGINT) { _ in log("\ninterrompido; a metade fica no bootloader até você rodar de novo ou apertar reset"); exit(130) }
RunLoop.main.run()

#tag Module
Protected Module Testing
	#tag Method, Flags = &h1
		Protected Sub RunTests()
		  If Not TestCompress() Then MsgBox("Compression failed")
		  If Not TestGZAppend() Then MsgBox("gzip append failed")
		  If Not TestGZWrite() Then MsgBox("gzip failed")
		  If Not TestGZRead() Then MsgBox("gunzip failed")
		  If Not TestTar() Then MsgBox("Tar failed")
		  If Not TestUntar() Then MsgBox("Untar failed")
		  If Not TestTarAppend() Then MsgBox("Tar append failed")
		  If Not TestZStream() Then MsgBox("ZStream failed")
		  If Not TestZWrite() Then MsgBox("Z write failed")
		  If Not TestZRead() Then MsgBox("Z read failed")
		  If Not TestGZStream() Then MsgBox("Z read failed")
		  If Not TestDeflate() Then MsgBox("Deflate read failed")
		  If Not TestUnzip() Then MsgBox("Zip read failed")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestCompress() As Boolean
		  Dim data As String
		  Dim rand As New Random
		  For i As Integer = 0 To 999
		    data = data + "Hello! "
		    If Rand.InRange(0, 5) = 5 Then data = data + Str(rand.InRange(0, 1000))
		  Next
		  Return _
		  (zlib.Uncompress(zlib.Compress(data, 9)) = data) And _
		  (zlib.Uncompress(zlib.Compress(data), data.LenB) = data) And _
		  (zlib.Uncompress(zlib.Compress(data, 9), data.LenB) = data)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestDeflate() As Boolean
		  Dim dlg As New OpenDialog
		  dlg.Title = CurrentMethodName + " - Select a file to deflate"
		  Dim f As FolderItem = dlg.ShowModal
		  If f = Nil Then Return False
		  Dim g As FolderItem = f.Parent.Child(f.Name + ".gz")
		  
		  If Not zlib.Deflate(f, g) Then
		    If g.Exists Then g.Delete
		    Return False
		  End If
		  
		  Dim output As New MemoryBlock(0)
		  Dim oustrt As New BinaryStream(output)
		  Dim bs As BinaryStream = BinaryStream.Open(f)
		  If Not zlib.Deflate(bs, oustrt) Then Return False
		  bs.Close
		  oustrt.Close
		  
		  Dim inf As MemoryBlock = zlib.Inflate(output)
		  Dim def As String = zlib.Deflate(inf)
		  Return def = output
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestGZAppend() As Boolean
		  Dim dlg As New OpenDialog
		  dlg.Title = CurrentMethodName + " - Select a file to GZip"
		  Dim f As FolderItem = dlg.ShowModal
		  If f = Nil Then Return False
		  Dim bs As BinaryStream = BinaryStream.Open(f)
		  Dim g As FolderItem = f.Parent.Child(f.Name + ".deflate")
		  Dim gz As zlib.GZStream = zlib.GZStream.Create(g, True)
		  While Not bs.EOF
		    gz.Write(bs.Read(1024))
		  Wend
		  gz.Close
		  Return True
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestGZRead() As Boolean
		  Dim dlg As New OpenDialog
		  dlg.Title = CurrentMethodName + " - Select a GZip file to read"
		  Dim f As FolderItem = dlg.ShowModal
		  dlg.Filter = FileTypes1.ApplicationXGzip
		  If f = Nil Then Return False
		  Dim gz As zlib.GZStream = zlib.GZStream.Open(f)
		  Dim g As FolderItem = f.Parent.Child(f.Name + "_uncompressed")
		  Dim bs As BinaryStream = BinaryStream.Create(g, True)
		  While Not gz.EOF
		    bs.Write(gz.Read(1024))
		  Wend
		  bs.Close
		  gz.Close
		  Return True
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestGZStream() As Boolean
		  Dim src As String = "TestData123TestData123TestData123TestData123TestData123TestData123"
		  Dim cmp As String = zlib.GZip(src)
		  Dim tst As String = "1F8B080000000000000B0B492D2E71492C493434320E218F0900CFC2014542000000"
		  Dim gun As String = zlib.GUnZip(cmp)
		  Return tst = EncodeHex(cmp) And gun = src
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestGZWrite() As Boolean
		  Dim dlg As New OpenDialog
		  dlg.Title = CurrentMethodName + " - Select a file to GZip"
		  Dim f As FolderItem = dlg.ShowModal
		  If f = Nil Then Return False
		  Dim bs As BinaryStream = BinaryStream.Open(f)
		  Dim g As FolderItem = f.Parent.Child(f.Name + ".gz")
		  Dim tmp As BinaryStream = BinaryStream.Create(g, True)
		  tmp.Close
		  Dim gz As zlib.GZStream = zlib.GZStream.Create(g)
		  gz.Level = 9
		  gz.Strategy = 3
		  While Not bs.EOF
		    gz.Write(bs.Read(1024))
		  Wend
		  bs.Close
		  gz.Close
		  Return True
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestTar() As Boolean
		  Dim sdlg As New SaveAsDialog
		  sdlg.Title = CurrentMethodName + " - Create TAR file"
		  sdlg.Filter = FileTypes1.ApplicationXTar
		  sdlg.SuggestedFileName = "TestArchive"
		  Dim f As FolderItem = sdlg.ShowModal
		  If f = Nil Then Return False
		  Dim tar As zlib.TapeArchive = zlib.TapeArchive.Create(f)
		  Dim odlg As New OpenDialog
		  odlg.Title = CurrentMethodName + " - Add files to TAR"
		  odlg.MultiSelect = True
		  If odlg.ShowModal = Nil Then Return False
		  For i As Integer = 0 To odlg.Count - 1
		    If Not tar.AppendFile(odlg.Item(i)) Then Return False
		  Next
		  tar.Close
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestTarAppend() As Boolean
		  Dim odlg As New OpenDialog
		  odlg.Title = CurrentMethodName + " - Open TAR file for appending"
		  odlg.Filter = FileTypes1.ApplicationXTar
		  Dim f As FolderItem = odlg.ShowModal
		  If f = Nil Then Return False
		  Dim tar As zlib.TapeArchive = zlib.TapeArchive.Open(f)
		  odlg.Filter = ""
		  odlg.Title = CurrentMethodName + " - Add files to TAR"
		  odlg.MultiSelect = True
		  If odlg.ShowModal = Nil Then Return False
		  For i As Integer = 0 To odlg.Count - 1
		    If Not tar.AppendFile(odlg.Item(i)) Then Return False
		  Next
		  tar.Close
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestUntar() As Boolean
		  Dim odlg As New OpenDialog
		  odlg.Title = CurrentMethodName + " - Open TAR file for extraction"
		  odlg.Filter = FileTypes1.ApplicationXTar
		  
		  Dim tarf As FolderItem = odlg.ShowModal
		  If tarf = Nil Then Return False
		  
		  Dim sfdlg As New SelectFolderDialog
		  sfdlg.Title = CurrentMethodName + " - Choose folder to extract into"
		  Dim target As FolderItem = sfdlg.ShowModal
		  If target = Nil Then Return False
		  Dim tar As zlib.TapeArchive = zlib.TapeArchive.Open(tarf)
		  'tar.ValidateChecksums = False
		  Dim bs As BinaryStream
		  
		  Do
		    If bs <> Nil Then bs.Close
		    Dim f As FolderItem = target.Child(tar.CurrentName)
		    bs = BinaryStream.Create(f, True)
		  Loop Until Not tar.MoveNext(bs)
		  tar.Close
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestUnzip() As Boolean
		  Dim odlg As New OpenDialog
		  odlg.Title = CurrentMethodName + " - Open ZIP file for extraction"
		  odlg.Filter = FileTypes1.ApplicationZip
		  
		  Dim zipf As FolderItem = odlg.ShowModal
		  If zipf = Nil Then Return False
		  
		  Dim sfdlg As New SelectFolderDialog
		  sfdlg.Title = CurrentMethodName + " - Choose folder to extract into"
		  Dim target As FolderItem = sfdlg.ShowModal
		  If target = Nil Then Return False
		  Dim out() As FolderItem = zlib.ReadZip(zipf, target, True)
		  Return UBound(out) > -1
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestZRead() As Boolean
		  Dim dlg As New OpenDialog
		  dlg.Title = CurrentMethodName + " - Select a Z-compressed file to read"
		  Dim f As FolderItem = dlg.ShowModal
		  dlg.Filter = FileTypes1.ApplicationXCompress
		  If f = Nil Then Return False
		  Dim g As FolderItem = f.Parent.Child(f.Name + "_uncompressed")
		  If Not zlib.Inflate(f, g) Then Return False
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestZStream() As Boolean
		  Dim cmp As New MemoryBlock(0)
		  Dim bs As New BinaryStream(cmp)
		  Dim z As zlib.ZStream = zlib.ZStream.Create(bs)
		  Dim src As String = "TestData123TestData123TestData123TestData123TestData123TestData123"
		  z.Write(src)
		  z.Close
		  bs.Close
		  If DecodeHex("789C0B492D2E71492C493434320E218F0900F29E1621") <> cmp Then Return False
		  bs = New BinaryStream(cmp)
		  z = z.Open(bs)
		  Dim decm As String
		  Do Until z.EOF
		    decm = decm + z.Read(64)
		  Loop
		  Return decm = src
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TestZWrite() As Boolean
		  Dim dlg As New OpenDialog
		  dlg.Title = CurrentMethodName + " - Select a file to Z-compress"
		  Dim f As FolderItem = dlg.ShowModal
		  If f = Nil Then Return False
		  Dim g As FolderItem = f.Parent.Child(f.Name + ".z")
		  If Not zlib.Deflate(f, g, 9) Then Return False
		  Return True
		End Function
	#tag EndMethod


End Module
#tag EndModule

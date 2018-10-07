#tag Class
Protected Class ZipArchive
	#tag Method, Flags = &h0
		Sub Close()
		  If mArchiveStream <> Nil Then mArchiveStream.Close
		  If mZipStream <> Nil Then mZipStream.Close
		  mArchiveStream = Nil
		  mZipStream = Nil
		  mIndex = -1
		  mDirectoryHeaderOffset = 0
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(ArchiveStream As BinaryStream)
		  mArchiveStream = ArchiveStream
		  mArchiveStream.LittleEndian = True
		  If Not Me.Reset(0) Then Raise New zlibException(ERR_NOT_ZIPPED)
		  mZipStream = ZStream.Open(mArchiveStream, RAW_ENCODING)
		  mZipStream.BufferedReading = False
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Function ConvertDate(NewDate As Date) As Pair
		  ' Convert the passed Date object into MS-DOS style datestamp and timestamp (16 bits each)
		  ' The DOS format has a resolution of two seconds, no concept of time zones, and is valid 
		  ' for dates between 1/1/1980 and 12/31/2107
		  
		  Dim h, m, s, dom, mon, year As UInt32
		  Dim dt, tm As UInt16
		  h = NewDate.Hour
		  m = NewDate.Minute
		  s = NewDate.Second
		  dom = NewDate.Day
		  mon = NewDate.Month
		  year = NewDate.Year - 1980
		  
		  If year > 127 Then Raise New OutOfBoundsException
		  
		  dt = dom
		  dt = dt Or ShiftLeft(mon, 5)
		  dt = dt Or ShiftLeft(year, 9)
		  
		  tm = s \ 2
		  tm = tm Or ShiftLeft(m, 5)
		  tm = tm Or ShiftLeft(h, 11)
		  
		  Return dt:tm
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Function ConvertDate(Dt As UInt16, tm As UInt16) As Date
		  ' Convert the passed MS-DOS style date and time into a Date object. 
		  ' The DOS format has a resolution of two seconds, no concept of time zones, 
		  ' and is valid for dates between 1/1/1980 and 12/31/2107
		  
		  Dim h, m, s, dom, mon, year As Integer
		  h = ShiftRight(tm, 11)
		  m = ShiftRight(tm, 5) And &h3F
		  s = (tm And &h1F) * 2
		  dom = dt And &h1F
		  mon = ShiftRight(dt, 5) And &h0F
		  year = (ShiftRight(dt, 9) And &h7F) + 1980
		  
		  Return New Date(year, mon, dom, h, m, s)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Count() As Integer
		  Return mDirectoryFooter.ThisRecordCount
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Destructor()
		  Me.Close()
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function LastError() As Integer
		  Return mLastError
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function MoveNext(ExtractTo As FolderItem, Overwrite As Boolean) As Boolean
		  Dim bs As BinaryStream
		  If Not ExtractTo.Directory Then bs = BinaryStream.Create(ExtractTo, Overwrite)
		  Return Me.MoveNext(bs)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function MoveNext(ExtractTo As Writeable) As Boolean
		  If mDirectoryHeaderOffset = 0 Then Raise New IOException
		  ' extract the current item
		  If ExtractTo <> Nil Then
		    Select Case mCurrentFile.Method
		    Case 0 ' not compressed
		      If mCurrentFile.UncompressedSize > 0 Then ExtractTo.Write(mArchiveStream.Read(mCurrentFile.CompressedSize))
		    Case 8 ' deflated
		      mZipStream.Reset
		      Dim p As UInt64 = mArchiveStream.Position
		      If ValidateChecksums Then mCurrentCRC = 0 Else mCurrentCRC = mCurrentFile.CRC32
		      Do Until mArchiveStream.Position - p >= mCurrentFile.CompressedSize
		        Dim offset As UInt64 = mArchiveStream.Position - p
		        Dim sz As Integer = Min(mCurrentFile.CompressedSize - offset, CHUNK_SIZE)
		        Dim data As MemoryBlock = mZipStream.Read(sz)
		        If data.Size > 0 Then
		          If ValidateChecksums Then mCurrentCRC = CRC32(data, mCurrentCRC, data.Size)
		          ExtractTo.Write(data)
		        End If
		      Loop
		      If ValidateChecksums And (mCurrentCRC <> mCurrentFile.CRC32) Then
		        mLastError = ERR_CHECKSUM_MISMATCH
		        Return False
		      End If
		    Else
		      mLastError = ERR_UNSUPPORTED_COMPRESSION
		      Return False
		    End Select
		  Else
		    mArchiveStream.Position = mArchiveStream.Position + mCurrentFile.CompressedSize
		  End If
		  If ValidateChecksums Then mRunningCRC = CRC32Combine(mRunningCRC, mCurrentCRC, mCurrentFile.UncompressedSize)
		  
		  ' read the next entry header
		  If mArchiveStream.Position >= mDirectoryHeaderOffset Then
		    mLastError = ERR_END_ARCHIVE
		    Return False
		  End If
		  mIndex = mIndex + 1
		  mCurrentFile.StringValue(True) = mArchiveStream.Read(mCurrentFile.Size)
		  If mCurrentFile.Signature <> FILE_SIGNATURE Then
		    mLastError = ERR_INVALID_ENTRY
		    Return False
		  End If
		  mCurrentName = mArchiveStream.Read(mCurrentFile.FilenameLength)
		  mCurrentExtra = mArchiveStream.Read(mCurrentFile.ExtraLength)
		  
		  If BitAnd(mCurrentFile.Flag, 4) = 4 And mCurrentFile.CompressedSize = 0 Then ' footer follows
		    Dim footer As ZipFileFooter
		    footer.StringValue(True) = mArchiveStream.Read(footer.Size)
		    If footer.Signature <> FILE_FOOTER_SIGNATURE Then
		      mArchiveStream.Position = mArchiveStream.Position - footer.Size
		    Else
		      mCurrentFile.CompressedSize = footer.ComressedSize
		      mCurrentFile.UncompressedSize = footer.UncompressedSize
		    End If
		  End If
		  mCurrentDataOffset = mArchiveStream.Position
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		 Shared Function Open(ZipFile As FolderItem) As zlib.ZipArchive
		  Return New ZipArchive(BinaryStream.Open(ZipFile))
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Reset(Index As Integer = 0) As Boolean
		  mArchiveStream.Position = mArchiveStream.Length - 4
		  mDirectoryHeaderOffset = 0
		  mDirectoryHeader.StringValue(True) = ""
		  mRunningCRC = 0
		  Do Until mDirectoryHeaderOffset > 0
		    If mArchiveStream.ReadUInt32 = DIRECTORY_FOOTER_HEADER Then
		      mArchiveStream.Position = mArchiveStream.Position - 4
		      mDirectoryFooter.StringValue(True) = mArchiveStream.Read(mDirectoryFooter.Size)
		      mArchiveStream.Position = mDirectoryFooter.Offset
		      mDirectoryHeaderOffset = mArchiveStream.Position
		      mDirectoryHeader.StringValue(True) = mArchiveStream.Read(mDirectoryHeader.Size)
		      mArchiveName = mArchiveStream.Read(mDirectoryHeader.FilenameLength)
		      mExtraData = mArchiveStream.Read(mDirectoryHeader.ExtraLength)
		      mArchiveComment = mArchiveStream.Read(mDirectoryHeader.CommentLength)
		      If mDirectoryFooter.ThisRecordCount = 0 Then
		        mIndex = -1
		        Return True
		      End If
		    Else
		      mArchiveStream.Position = mArchiveStream.Position - 5
		    End If
		  Loop Until mArchiveStream.Position < 22
		  
		  mIndex = -1
		  mCurrentExtra = Nil
		  mCurrentFile.StringValue(True) = ""
		  mCurrentName = ""
		  If mDirectoryHeaderOffset = 0 Then
		    mLastError = ERR_NOT_ZIPPED
		    Return False
		  End If
		  
		  mArchiveStream.Position = mDirectoryHeader.Offset
		  Do
		    If Not Me.MoveNext(Nil) Then Return (Index = -1 And mLastError = ERR_END_ARCHIVE)
		  Loop Until mIndex >= Index And Index > -1
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Test() As Boolean
		  If Not Me.Reset(0) Then Return False
		  Dim vc As Boolean = ValidateChecksums
		  ValidateChecksums = True
		  Dim nullstream As New BinaryStream(New MemoryBlock(0))
		  nullstream.Close
		  Do
		  Loop Until Not Me.MoveNext(nullstream)
		  ValidateChecksums = vc
		  Return mLastError = ERR_END_ARCHIVE
		End Function
	#tag EndMethod


	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  If mArchiveComment <> Nil Then Return mArchiveComment
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  mArchiveComment = value
			End Set
		#tag EndSetter
		ArchiveComment As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  If mArchiveName <> Nil Then Return mArchiveName
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  mArchiveName = value
			End Set
		#tag EndSetter
		ArchiveName As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  Select Case True
			  Case BitAnd(mDirectoryHeader.Flag, 1) = 1 And BitAnd(mDirectoryHeader.Flag, 2) = 2
			    Return 1 ' fastest
			  Case BitAnd(mDirectoryHeader.Flag, 1) = 1 And BitAnd(mDirectoryHeader.Flag, 2) <> 2
			    Return 9 ' best
			  Case BitAnd(mDirectoryHeader.Flag, 1) <> 1 And BitAnd(mDirectoryHeader.Flag, 2) <> 2
			    Return 6 ' normal
			  Case BitAnd(mDirectoryHeader.Flag, 1) <> 1 And BitAnd(mDirectoryHeader.Flag, 2) = 2
			    Return 3 ' fast
			  Case mDirectoryHeader.Method = 0
			    Return 0 ' none
			  End Select
			  
			  
			End Get
		#tag EndGetter
		CompressionLevel As Integer
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  If mIndex > -1 Then Return mCurrentFile.CRC32 Else Return 0
			End Get
		#tag EndGetter
		CurrentCRC32 As UInt32
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  Return mCurrentDataOffset
			End Get
		#tag EndGetter
		CurrentDataOffset As UInt64
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  If mIndex > -1 Then Return mCurrentExtra
			End Get
		#tag EndGetter
		CurrentExtraData As MemoryBlock
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  Return mIndex
			End Get
		#tag EndGetter
		CurrentIndex As Integer
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  If mIndex = -1 Then Return Nil
			  
			  Return ConvertDate(mCurrentFile.ModDate, mCurrentFile.ModTime)
			End Get
		#tag EndGetter
		CurrentModificationDate As Date
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  If mIndex > -1 Then Return mCurrentName
			End Get
		#tag EndGetter
		CurrentName As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  If mIndex > -1 Then Return mCurrentFile.CompressedSize Else Return -1
			End Get
		#tag EndGetter
		CurrentSize As UInt32
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  If mIndex > -1 Then Return mCurrentFile.UncompressedSize Else Return -1
			End Get
		#tag EndGetter
		CurrentUncompressedSize As UInt32
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  Return BitAnd(mDirectoryHeader.Flag, 1) = 1
			End Get
		#tag EndGetter
		IsEncrypted As Boolean
	#tag EndComputedProperty

	#tag Property, Flags = &h21
		Private mArchiveComment As MemoryBlock
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mArchiveName As MemoryBlock
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mArchiveStream As BinaryStream
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mCurrentCRC As UInt32
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mCurrentDataOffset As UInt64
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mCurrentExtra As MemoryBlock
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mCurrentFile As ZipFileHeader
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mCurrentName As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mDirectoryFooter As ZipDirectoryFooter
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mDirectoryHeader As ZipDirectoryHeader
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mDirectoryHeaderOffset As UInt32
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mExtraData As MemoryBlock
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mIndex As Integer = -1
	#tag EndProperty

	#tag Property, Flags = &h1
		Protected mLastError As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mRunningCRC As UInt32
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mSpanOffset As UInt32 = 0
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mZipStream As zlib.ZStream
	#tag EndProperty

	#tag Property, Flags = &h0
		ValidateChecksums As Boolean = True
	#tag EndProperty


	#tag Constant, Name = DIRECTORY_FOOTER_HEADER, Type = Double, Dynamic = False, Default = \"&h06054b50", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = DIRECTORY_SIGNATURE, Type = Double, Dynamic = False, Default = \"&h02014b50", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = FILE_FOOTER_SIGNATURE, Type = Double, Dynamic = False, Default = \"&h08074b50", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = FILE_SIGNATURE, Type = Double, Dynamic = False, Default = \"&h04034b50", Scope = Protected
	#tag EndConstant


	#tag Structure, Name = ZipDirectoryFooter, Flags = &h21
		Signature As UInt32
		  ThisDisk As UInt16
		  FirstDisk As UInt16
		  ThisRecordCount As UInt16
		  TotalRecordCount As UInt16
		  DirectorySize As UInt32
		  Offset As UInt32
		CommentLength As UInt16
	#tag EndStructure

	#tag Structure, Name = ZipDirectoryHeader, Flags = &h21
		Signature As UInt32
		  Version As UInt16
		  VersionNeeded As UInt16
		  Flag As UInt16
		  Method As UInt16
		  ModTime As UInt16
		  ModDate As UInt16
		  CRC32 As UInt32
		  CompressedSize As UInt32
		  UncompressedSize As UInt32
		  FilenameLength As UInt16
		  ExtraLength As UInt16
		  CommentLength As UInt16
		  DiskNumber As UInt16
		  InternalAttributes As UInt16
		  ExternalAttributes As UInt32
		Offset As UInt32
	#tag EndStructure

	#tag Structure, Name = ZipEntryFooter, Flags = &h21
		Signature As UInt32
		  CRC32 As UInt32
		  ComressedSize As UInt32
		UncompressedSize As UInt32
	#tag EndStructure

	#tag Structure, Name = ZipEntryHeader, Flags = &h21
		Signature As UInt32
		  Version As UInt16
		  Flag As UInt16
		  Method As UInt16
		  ModTime As UInt16
		  ModDate As UInt16
		  CRC32 As UInt32
		  CompressedSize As UInt32
		  UncompressedSize As UInt32
		  FilenameLength As UInt16
		ExtraLength As UInt16
	#tag EndStructure


	#tag ViewBehavior
		#tag ViewProperty
			Name="ArchiveComment"
			Group="Behavior"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="ArchiveName"
			Group="Behavior"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="CompressionLevel"
			Group="Behavior"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="IsEncrypted"
			Group="Behavior"
			Type="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			InheritedFrom="Object"
		#tag EndViewProperty
		#tag ViewProperty
			Name="ValidateChecksums"
			Group="Behavior"
			InitialValue="True"
			Type="Boolean"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass

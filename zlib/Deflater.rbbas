#tag Class
Protected Class Deflater
	#tag Method, Flags = &h0
		Function Avail_In() As UInt32
		  Return zstream.avail_in
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(CompressionLevel As Integer = zlib.Z_DEFAULT_COMPRESSION)
		  zstream.zalloc = Nil
		  zstream.zfree = Nil
		  zstream.opaque = Nil
		  mLastError = deflateInit_(zstream, CompressionLevel, zlib.Version, zstream.Size)
		  If mLastError <> Z_OK Then Raise New zlibException(mLastError)
		  mLevel = CompressionLevel
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Deflate(Data As MemoryBlock, Flushing As Integer = zlib.Z_NO_FLUSH) As MemoryBlock
		  Dim outbuff As New MemoryBlock(CHUNK_SIZE)
		  Dim ret As New MemoryBlock(0)
		  Dim retstream As New BinaryStream(ret)
		  Dim instream As New BinaryStream(Data)
		  Do
		    Dim chunk As MemoryBlock = instream.Read(CHUNK_SIZE)
		    zstream.avail_in = chunk.Size
		    zstream.next_in = chunk
		    Do
		      zstream.next_out = outbuff
		      zstream.avail_out = outbuff.Size
		      mLastError = zlib.deflate(zstream, Flushing)
		      If mLastError = Z_STREAM_ERROR Then Raise New zlibException(mLastError)
		      Dim have As UInt32 = CHUNK_SIZE - zstream.avail_out
		      If have > 0 Then retstream.Write(outbuff.StringValue(0, have))
		    Loop Until mLastError <> Z_OK Or zstream.avail_out <> 0
		  Loop Until instream.EOF
		  retstream.Close
		  Return ret
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Destructor()
		  If IsOpen Then mLastError = zlib.deflateEnd(zstream)
		  zstream.zfree = Nil
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function IsOpen() As Boolean
		  Return zstream.zfree <> Nil
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function LastError() As Integer
		  Return mLastError
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Reset()
		  If zstream.zalloc <> Nil Then
		    mLastError = deflateReset(zstream)
		  End If
		End Sub
	#tag EndMethod


	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  Return mLevel
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  If Not IsOpen Then Raise New NilObjectException
			  mLastError = deflateParams(zstream, value, mStrategy)
			  If mLastError = Z_OK Then
			    mLevel = value
			  Else
			    Raise New zlibException(mLastError)
			  End If
			  
			End Set
		#tag EndSetter
		Level As Integer
	#tag EndComputedProperty

	#tag Property, Flags = &h1
		Protected mLastError As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLevel As Integer = Z_DEFAULT_COMPRESSION
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mStrategy As Integer = Z_DEFAULT_STRATEGY
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  Return mStrategy
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  If Not IsOpen Then Raise New NilObjectException
			  mLastError = deflateParams(zstream, mLevel, value)
			  If mLastError = Z_OK Then
			    mStrategy = value
			  Else
			    Raise New zlibException(mLastError)
			  End If
			  
			End Set
		#tag EndSetter
		Strategy As Integer
	#tag EndComputedProperty

	#tag Property, Flags = &h1
		Protected zstream As z_stream
	#tag EndProperty


	#tag Constant, Name = CHUNK_SIZE, Type = Double, Dynamic = False, Default = \"16384", Scope = Private
	#tag EndConstant


	#tag ViewBehavior
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			InheritedFrom="Object"
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
	#tag EndViewBehavior
End Class
#tag EndClass

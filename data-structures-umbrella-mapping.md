# Umbrella Product Mapping

Definitive mapping of every multi-product package in swift-primitives.
For each package: umbrella product, Core target, variant products, and test support.

Product names use spaces (Package.swift); module names use underscores (`import`).

---

## Section 1: Multi-Product Packages (29)

---

### swift-affine-primitives

**Umbrella**: Affine Primitives -> `Affine_Primitives`

**Variants**:
- Affine Primitives Core -> `Affine_Primitives_Core` (internal target, not a product)
- Affine Primitives Standard Library Integration -> `Affine_Primitives_Standard_Library_Integration`

**Test Support**: Affine Primitives Test Support -> `Affine_Primitives_Test_Support`

---

### swift-algebra-primitives

**Umbrella**: Algebra Primitives -> `Algebra_Primitives`

**Variants**:
- Algebra Primitives Core -> `Algebra_Primitives_Core`

**Test Support**: Algebra Primitives Test Support -> `Algebra_Primitives_Test_Support`

---

### swift-array-primitives

**Umbrella**: Array Primitives -> `Array_Primitives`

**Variants**:
- Array Primitives Core -> `Array_Primitives_Core`
- Array Small Primitives -> `Array_Small_Primitives`
- Array Static Primitives -> `Array_Static_Primitives`
- Array Fixed Primitives -> `Array_Fixed_Primitives`
- Array Dynamic Primitives -> `Array_Dynamic_Primitives`
- Array Bounded Primitives -> `Array_Bounded_Primitives`

**Test Support**: Array Primitives Test Support -> `Array_Primitives_Test_Support`

---

### swift-ascii-parser-primitives

**Umbrella**: ASCII Parser Primitives -> `ASCII_Parser_Primitives`

**Variants**:
- ASCII Parser Primitives Core -> `ASCII_Parser_Primitives_Core` (internal target, not a product)
- ASCII Decimal Parser Primitives -> `ASCII_Decimal_Parser_Primitives`
- ASCII Hexadecimal Parser Primitives -> `ASCII_Hexadecimal_Parser_Primitives`
- Parseable Integer Primitives -> `Parseable_Integer_Primitives`

**Test Support**: ASCII Parser Primitives Test Support -> `ASCII_Parser_Primitives_Test_Support`

---

### swift-ascii-serializer-primitives

**Umbrella**: ASCII Serializer Primitives -> `ASCII_Serializer_Primitives`

**Variants**:
- ASCII Serializer Primitives Core -> `ASCII_Serializer_Primitives_Core` (internal target, not a product)
- ASCII Decimal Serializer Primitives -> `ASCII_Decimal_Serializer_Primitives`
- ASCII Hexadecimal Serializer Primitives -> `ASCII_Hexadecimal_Serializer_Primitives`
- Serializable Integer Primitives -> `Serializable_Integer_Primitives`

**Test Support**: ASCII Serializer Primitives Test Support -> `ASCII_Serializer_Primitives_Test_Support`

---

### swift-async-primitives

**Umbrella**: Async Primitives -> `Async_Primitives`

**Variants**:
- Async Primitives Core -> `Async_Primitives_Core`
- Async Mutex Primitives -> `Async_Mutex_Primitives`
- Async Bridge Primitives -> `Async_Bridge_Primitives`
- Async Promise Primitives -> `Async_Promise_Primitives`
- Async Publication Primitives -> `Async_Publication_Primitives`
- Async Barrier Primitives -> `Async_Barrier_Primitives`
- Async Completion Primitives -> `Async_Completion_Primitives`
- Async Channel Primitives -> `Async_Channel_Primitives`
- Async Broadcast Primitives -> `Async_Broadcast_Primitives`
- Async Timer Primitives -> `Async_Timer_Primitives`
- Async Waiter Primitives -> `Async_Waiter_Primitives`

**Test Support**: Async Primitives Test Support -> `Async_Primitives_Test_Support`

---

### swift-binary-parser-primitives

**Umbrella**: Binary Parser Primitives -> `Binary_Parser_Primitives`

**Variants**:
- Binary Parser Primitives Core -> `Binary_Parser_Primitives_Core` (internal target, not a product)
- Binary Input Primitives -> `Binary_Input_Primitives`
- Binary Input View Primitives -> `Binary_Input_View_Primitives`
- Binary Machine Primitives -> `Binary_Machine_Primitives`
- Binary Borrowed Primitives -> `Binary_Borrowed_Primitives`
- Binary Parse Primitives -> `Binary_Parse_Primitives`
- Binary LEB128 Primitives -> `Binary_LEB128_Primitives`
- Binary Coder Primitives -> `Binary_Coder_Primitives`
- Binary Integer Primitives -> `Binary_Integer_Primitives`

**Test Support**: Binary Parser Primitives Test Support -> `Binary_Parser_Primitives_Test_Support`

---

### swift-binary-primitives

**Umbrella**: Binary Primitives -> `Binary_Primitives`

**Variants**:
- Binary Primitives Core -> `Binary_Primitives_Core`
- Binary Format Primitives -> `Binary_Format_Primitives`
- Binary Serializable Primitives -> `Binary_Serializable_Primitives`

**Test Support**: Binary Primitives Test Support -> `Binary_Primitives_Test_Support`

---

### swift-bit-vector-primitives

**Umbrella**: Bit Vector Primitives -> `Bit_Vector_Primitives`

**Variants**:
- Bit Vector Primitives Core -> `Bit_Vector_Primitives_Core`
- Bit Vector Static Primitives -> `Bit_Vector_Static_Primitives`
- Bit Vector Bounded Primitives -> `Bit_Vector_Bounded_Primitives`
- Bit Vector Inline Primitives -> `Bit_Vector_Inline_Primitives`
- Bit Vector Dynamic Primitives -> `Bit_Vector_Dynamic_Primitives`

**Test Support**: Bit Vector Primitives Test Support -> `Bit_Vector_Primitives_Test_Support`

---

### swift-buffer-primitives

**Umbrella**: Buffer Primitives -> `Buffer_Primitives`

**Variants**:
- Buffer Primitives Core -> `Buffer_Primitives_Core`
- Buffer Ring Primitives -> `Buffer_Ring_Primitives`
- Buffer Ring Inline Primitives -> `Buffer_Ring_Inline_Primitives`
- Buffer Linear Primitives -> `Buffer_Linear_Primitives`
- Buffer Linear Inline Primitives -> `Buffer_Linear_Inline_Primitives`
- Buffer Linear Small Primitives -> `Buffer_Linear_Small_Primitives`
- Buffer Slab Primitives -> `Buffer_Slab_Primitives`
- Buffer Slab Inline Primitives -> `Buffer_Slab_Inline_Primitives`
- Buffer Linked Primitives -> `Buffer_Linked_Primitives`
- Buffer Linked Inline Primitives -> `Buffer_Linked_Inline_Primitives`
- Buffer Slots Primitives -> `Buffer_Slots_Primitives`
- Buffer Arena Primitives -> `Buffer_Arena_Primitives`
- Buffer Arena Inline Primitives -> `Buffer_Arena_Inline_Primitives`

**Internal targets** (not products):
- Buffer Ring Primitives Core -> `Buffer_Ring_Primitives_Core`
- Buffer Linear Primitives Core -> `Buffer_Linear_Primitives_Core`
- Buffer Slab Primitives Core -> `Buffer_Slab_Primitives_Core`
- Buffer Linked Primitives Core -> `Buffer_Linked_Primitives_Core`
- Buffer Arena Primitives Core -> `Buffer_Arena_Primitives_Core`
- Buffer Slots Primitives Core -> `Buffer_Slots_Primitives_Core`
- Buffer Aligned Primitives Core -> `Buffer_Aligned_Primitives_Core`
- Buffer Unbounded Primitives Core -> `Buffer_Unbounded_Primitives_Core`

**Test Support**: Buffer Primitives Test Support -> `Buffer_Primitives_Test_Support`

---

### swift-graph-primitives

**Umbrella**: Graph Primitives -> `Graph_Primitives`

**Variants**:
- Graph Primitives Core -> `Graph_Primitives_Core`
- Graph DFS Primitives -> `Graph_DFS_Primitives`
- Graph BFS Primitives -> `Graph_BFS_Primitives`
- Graph Topological Primitives -> `Graph_Topological_Primitives`
- Graph Reachable Primitives -> `Graph_Reachable_Primitives`
- Graph Dead Primitives -> `Graph_Dead_Primitives`
- Graph SCC Primitives -> `Graph_SCC_Primitives`
- Graph Cycles Primitives -> `Graph_Cycles_Primitives`
- Graph Transitive Closure Primitives -> `Graph_Transitive_Closure_Primitives`
- Graph Path Exists Primitives -> `Graph_Path_Exists_Primitives`
- Graph Shortest Path Primitives -> `Graph_Shortest_Path_Primitives`
- Graph Weighted Path Primitives -> `Graph_Weighted_Path_Primitives`
- Graph Payload Map Primitives -> `Graph_Payload_Map_Primitives`
- Graph Subgraph Primitives -> `Graph_Subgraph_Primitives`
- Graph Reverse Primitives -> `Graph_Reverse_Primitives`
- Graph Backward Reachable Primitives -> `Graph_Backward_Reachable_Primitives`

**Test Support**: Graph Primitives Test Support -> `Graph_Primitives_Test_Support`

---

### swift-hash-table-primitives

**Umbrella**: Hash Table Primitives -> `Hash_Table_Primitives`

**Variants**:
- Hash Table Primitives Core -> `Hash_Table_Primitives_Core`
- Hash Table Accessor Primitives -> `Hash_Table_Accessor_Primitives` (internal target, not a product)

**Test Support**: Hash Table Primitives Test Support -> `Hash_Table_Primitives_Test_Support`

---

### swift-heap-primitives

**Umbrella**: Heap Primitives -> `Heap_Primitives`

**Variants**:
- Heap Primitives Core -> `Heap_Primitives_Core`
- Heap Binary Primitives -> `Heap_Binary_Primitives`
- Heap Fixed Primitives -> `Heap_Fixed_Primitives`
- Heap Static Primitives -> `Heap_Static_Primitives`
- Heap Small Primitives -> `Heap_Small_Primitives`
- Heap Min Primitives -> `Heap_Min_Primitives`
- Heap Max Primitives -> `Heap_Max_Primitives`
- Heap MinMax Primitives -> `Heap_MinMax_Primitives`

**Test Support**: Heap Primitives Test Support -> `Heap_Primitives_Test_Support`

---

### swift-kernel-primitives

**Umbrella**: Kernel Primitives -> `Kernel_Primitives`

**Variants**:
- Kernel Primitives Core -> `Kernel_Primitives_Core`
- Kernel Clock Primitives -> `Kernel_Clock_Primitives`
- Kernel Descriptor Primitives -> `Kernel_Descriptor_Primitives`
- Kernel Environment Primitives -> `Kernel_Environment_Primitives`
- Kernel Error Primitives -> `Kernel_Error_Primitives`
- Kernel IO Primitives -> `Kernel_IO_Primitives`
- Kernel Memory Primitives -> `Kernel_Memory_Primitives`
- Kernel Permission Primitives -> `Kernel_Permission_Primitives`
- Kernel Process Primitives -> `Kernel_Process_Primitives`
- Kernel Random Primitives -> `Kernel_Random_Primitives`
- Kernel String Primitives -> `Kernel_String_Primitives`
- Kernel Syscall Primitives -> `Kernel_Syscall_Primitives`
- Kernel Time Primitives -> `Kernel_Time_Primitives`
- Kernel Outcome Primitives -> `Kernel_Outcome_Primitives`
- Kernel System Primitives -> `Kernel_System_Primitives`
- Kernel Path Primitives -> `Kernel_Path_Primitives`
- Kernel File Primitives -> `Kernel_File_Primitives`
- Kernel Socket Primitives -> `Kernel_Socket_Primitives`
- Kernel Thread Primitives -> `Kernel_Thread_Primitives`
- Kernel Event Primitives -> `Kernel_Event_Primitives`
- Kernel Terminal Primitives -> `Kernel_Terminal_Primitives`
- Kernel Glob Primitives -> `Kernel_Glob_Primitives`

**Test Support**: Kernel Primitives Test Support -> `Kernel_Primitives_Test_Support`

---

### swift-list-primitives

**Umbrella**: List Primitives -> `List_Primitives`

**Variants**:
- List Primitives Core -> `List_Primitives_Core`
- List Linked Primitives -> `List_Linked_Primitives`

**Test Support**: List Primitives Test Support -> `List_Primitives_Test_Support`

---

### swift-machine-primitives

**Umbrella**: Machine Primitives -> `Machine_Primitives`

**Variants**:
- Machine Primitives Core -> `Machine_Primitives_Core`
- Machine Value Primitives -> `Machine_Value_Primitives`
- Machine Capture Primitives -> `Machine_Capture_Primitives`
- Machine Transform Primitives -> `Machine_Transform_Primitives`
- Machine Combine Primitives -> `Machine_Combine_Primitives`
- Machine Next Primitives -> `Machine_Next_Primitives`
- Machine Finalize Primitives -> `Machine_Finalize_Primitives`
- Machine Frame Primitives -> `Machine_Frame_Primitives`
- Machine Node Primitives -> `Machine_Node_Primitives`
- Machine Program Primitives -> `Machine_Program_Primitives`
- Machine Convenience Primitives -> `Machine_Convenience_Primitives`

**Test Support**: Machine Primitives Test Support -> `Machine_Primitives_Test_Support`

---

### swift-memory-primitives

**Umbrella**: Memory Primitives -> `Memory_Primitives`

**Variants**:
- Memory Primitives Core -> `Memory_Primitives_Core`
- Memory Arena Primitives -> `Memory_Arena_Primitives`
- Memory Pool Primitives -> `Memory_Pool_Primitives`
- Memory Primitives Standard Library Integration -> `Memory_Primitives_Standard_Library_Integration` (internal target, not a product)

**Test Support**: Memory Primitives Test Support -> `Memory_Primitives_Test_Support`

---

### swift-numeric-primitives

**Umbrella**: Numeric Primitives -> `Numeric_Primitives`

**Variants**:
- Numeric Primitives Core -> `Numeric_Primitives_Core`
- Real Primitives -> `Real_Primitives`
- Integer Primitives -> `Integer_Primitives`

**Test Support**: Numeric Primitives Test Support -> `Numeric_Primitives_Test_Support`

---

### swift-parser-machine-primitives

**Umbrella**: Parser Machine Primitives -> `Parser_Machine_Primitives`

**Variants**:
- Parser Machine Core Primitives -> `Parser_Machine_Core_Primitives`
- Parser Machine Memoization Primitives -> `Parser_Machine_Memoization_Primitives`
- Parser Machine Compile Primitives -> `Parser_Machine_Compile_Primitives`
- Parser Machine Combinator Primitives -> `Parser_Machine_Combinator_Primitives`
- Parser Machine Parse Primitives -> `Parser_Machine_Parse_Primitives`

**Test Support**: Parser Machine Primitives Test Support -> `Parser_Machine_Primitives_Test_Support`

---

### swift-parser-primitives

**Umbrella**: Parser Primitives -> `Parser_Primitives`

**Variants**:
- Parser Primitives Core -> `Parser_Primitives_Core`
- Parser Error Primitives -> `Parser_Error_Primitives`
- Parser Match Primitives -> `Parser_Match_Primitives`
- Parser EndOfInput Primitives -> `Parser_EndOfInput_Primitives`
- Parser Constraint Primitives -> `Parser_Constraint_Primitives`
- Parser OneOf Primitives -> `Parser_OneOf_Primitives`
- Parser Map Primitives -> `Parser_Map_Primitives`
- Parser FlatMap Primitives -> `Parser_FlatMap_Primitives`
- Parser Filter Primitives -> `Parser_Filter_Primitives`
- Parser Conditional Primitives -> `Parser_Conditional_Primitives`
- Parser Optional Primitives -> `Parser_Optional_Primitives`
- Parser Skip Primitives -> `Parser_Skip_Primitives`
- Parser Many Primitives -> `Parser_Many_Primitives`
- Parser Take Primitives -> `Parser_Take_Primitives`
- Parser Consume Primitives -> `Parser_Consume_Primitives`
- Parser Discard Primitives -> `Parser_Discard_Primitives`
- Parser Prefix Primitives -> `Parser_Prefix_Primitives`
- Parser First Primitives -> `Parser_First_Primitives`
- Parser Tracked Primitives -> `Parser_Tracked_Primitives`
- Parser Spanned Primitives -> `Parser_Spanned_Primitives`
- Parser Span Primitives -> `Parser_Span_Primitives`
- Parser Locate Primitives -> `Parser_Locate_Primitives`
- Parser Peek Primitives -> `Parser_Peek_Primitives`
- Parser Not Primitives -> `Parser_Not_Primitives`
- Parser Always Primitives -> `Parser_Always_Primitives`
- Parser Fail Primitives -> `Parser_Fail_Primitives`
- Parser Rest Primitives -> `Parser_Rest_Primitives`
- Parser End Primitives -> `Parser_End_Primitives`
- Parser Lazy Primitives -> `Parser_Lazy_Primitives`
- Parser Trace Primitives -> `Parser_Trace_Primitives`
- Parser Backtrack Primitives -> `Parser_Backtrack_Primitives`
- Parser Parse Primitives -> `Parser_Parse_Primitives`
- Parser Byte Primitives -> `Parser_Byte_Primitives`
- Parser Literal Primitives -> `Parser_Literal_Primitives`
- Parser Conformance Primitives -> `Parser_Conformance_Primitives`

**Test Support**: Parser Primitives Test Support -> `Parser_Primitives_Test_Support`

---

### swift-pool-primitives

**Umbrella**: Pool Primitives -> `Pool_Primitives`

**Variants**:
- Pool Primitives Core -> `Pool_Primitives_Core`
- Pool Bounded Primitives -> `Pool_Bounded_Primitives`

**Test Support**: Pool Primitives Test Support -> `Pool_Primitives_Test_Support`

---

### swift-queue-primitives

**Umbrella**: Queue Primitives -> `Queue_Primitives`

**Variants**:
- Queue Primitives Core -> `Queue_Primitives_Core` (internal target, not a product)
- Queue Dynamic Primitives -> `Queue_Dynamic_Primitives` (internal target, not a product)
- Queue Fixed Primitives -> `Queue_Fixed_Primitives` (internal target, not a product)
- Queue Static Primitives -> `Queue_Static_Primitives` (internal target, not a product)
- Queue Small Primitives -> `Queue_Small_Primitives` (internal target, not a product)
- Queue Linked Primitives -> `Queue_Linked_Primitives` (internal target, not a product)
- Queue DoubleEnded Primitives -> `Queue_DoubleEnded_Primitives`
- Deque Primitives -> `Deque_Primitives` (alias for Queue DoubleEnded Primitives target)

**Test Support**: Queue Primitives Test Support -> `Queue_Primitives_Test_Support`

---

### swift-sequence-primitives

**Umbrella**: Sequence Primitives -> `Sequence_Primitives`

**Variants**:
- Sequence Primitives Core -> `Sequence_Primitives_Core` (internal target, not a product)
- Sequence Difference Primitives -> `Sequence_Difference_Primitives`
- Sequence Primitives Standard Library Integration -> `Sequence_Primitives_Standard_Library_Integration` (internal target, not a product)

**Test Support**: Sequence Primitives Test Support -> `Sequence_Primitives_Test_Support`

---

### swift-serializer-primitives

**Umbrella**: Serializer Primitives -> `Serializer_Primitives`

**Variants**:
- Serializer Primitives Core -> `Serializer_Primitives_Core`
- Serialization Primitives -> `Serialization_Primitives`

**Test Support**: Serialization Primitives Test Support -> `Serialization_Primitives_Test_Support`

---

### swift-slab-primitives

**Umbrella**: Slab Primitives -> `Slab_Primitives`

**Variants**:
- Slab Primitives Core -> `Slab_Primitives_Core`
- Slab Dynamic Primitives -> `Slab_Dynamic_Primitives`
- Slab Static Primitives -> `Slab_Static_Primitives`

**Test Support**: Slab Primitives Test Support -> `Slab_Primitives_Test_Support`

---

### swift-storage-primitives

**Umbrella**: Storage Primitives -> `Storage_Primitives`

**Variants**:
- Storage Primitives Core -> `Storage_Primitives_Core`
- Storage Heap Primitives -> `Storage_Heap_Primitives`
- Storage Inline Primitives -> `Storage_Inline_Primitives`
- Storage Pool Primitives -> `Storage_Pool_Primitives`
- Storage Arena Primitives -> `Storage_Arena_Primitives`
- Storage Pool Inline Primitives -> `Storage_Pool_Inline_Primitives`
- Storage Arena Inline Primitives -> `Storage_Arena_Inline_Primitives`
- Storage Slab Primitives -> `Storage_Slab_Primitives`
- Storage Split Primitives -> `Storage_Split_Primitives`

**Test Support**: Storage Primitives Test Support -> `Storage_Primitives_Test_Support`

---

### swift-test-primitives

**Umbrella**: Test Primitives -> `Test_Primitives`

**Variants**:
- Test Primitives Core -> `Test_Primitives_Core`
- Test Snapshot Primitives -> `Test_Snapshot_Primitives`
- Test Primitives Standard Library Integration -> `Test_Primitives_Standard_Library_Integration`

**Test Support**: Test Primitives Test Support -> `Test_Primitives_Test_Support`

---

### swift-time-primitives

**Umbrella**: Time Primitives -> `Time_Primitives`

**Variants**:
- Time Primitives Core -> `Time_Primitives_Core`
- Time Julian Primitives -> `Time_Julian_Primitives`

**Test Support**: Time Primitives Test Support -> `Time_Primitives_Test_Support`

---

### swift-tree-primitives

**Umbrella**: Tree Primitives -> `Tree_Primitives`

**Variants**:
- Tree Primitives Core -> `Tree_Primitives_Core`
- Tree N Bounded Primitives -> `Tree_N_Bounded_Primitives`
- Tree N Inline Primitives -> `Tree_N_Inline_Primitives`
- Tree N Small Primitives -> `Tree_N_Small_Primitives`
- Tree Unbounded Primitives -> `Tree_Unbounded_Primitives`
- Tree Keyed Primitives -> `Tree_Keyed_Primitives`

**Test Support**: Tree Primitives Test Support -> `Tree_Primitives_Test_Support`

---

## Section 2: Borderline Packages (Core + Umbrella + Test Support) (26)

These packages have internal Core targets but only expose a single umbrella product.
The umbrella re-exports Core + StdLib Integration (where present).
Where possible, prefer importing Core directly for narrower dependency surface.

---

### swift-bit-primitives

**Umbrella**: Bit Primitives -> `Bit_Primitives`

**Internal targets**:
- Bit Primitives Core -> `Bit_Primitives_Core`
- Bit Boolean Primitives -> `Bit_Boolean_Primitives`
- Bit Field Primitives -> `Bit_Field_Primitives`
- Bit Primitives Standard Library Integration -> `Bit_Primitives_Standard_Library_Integration`

**Test Support**: Bit Primitives Test Support -> `Bit_Primitives_Test_Support`

---

### swift-cardinal-primitives

**Umbrella**: Cardinal Primitives -> `Cardinal_Primitives`

**Internal targets**:
- Cardinal Primitives Core -> `Cardinal_Primitives_Core`
- Cardinal Primitives Standard Library Integration -> `Cardinal_Primitives_Standard_Library_Integration`

**Test Support**: Cardinal Primitives Test Support -> `Cardinal_Primitives_Test_Support`

---

### swift-ordinal-primitives

**Umbrella**: Ordinal Primitives -> `Ordinal_Primitives`

**Internal targets**:
- Ordinal Primitives Core -> `Ordinal_Primitives_Core`
- Ordinal Primitives Standard Library Integration -> `Ordinal_Primitives_Standard_Library_Integration`

**Test Support**: Ordinal Primitives Test Support -> `Ordinal_Primitives_Test_Support`

---

### swift-finite-primitives

**Umbrella**: Finite Primitives -> `Finite_Primitives`

**Internal targets**:
- Finite Primitives Core -> `Finite_Primitives_Core`

**Test Support**: Finite Primitives Test Support -> `Finite_Primitives_Test_Support`

---

### swift-index-primitives

**Umbrella**: Index Primitives -> `Index_Primitives`

**Internal targets**:
- Index Primitives Core -> `Index_Primitives_Core`

**Test Support**: Index Primitives Test Support -> `Index_Primitives_Test_Support`

---

### swift-vector-primitives

**Umbrella**: Vector Primitives -> `Vector_Primitives`

**Internal targets**:
- Vector Primitives Core -> `Vector_Primitives_Core`
- Vector Primitives Standard Library Integration -> `Vector_Primitives_Standard_Library_Integration`

**Test Support**: Vector Primitives Test Support -> `Vector_Primitives_Test_Support`

---

### swift-range-primitives

**Umbrella**: Range Primitives -> `Range_Primitives`

**Internal targets**:
- Range Primitives Core -> `Range_Primitives_Core`

**Test Support**: Range Primitives Test Support -> `Range_Primitives_Test_Support`

---

### swift-sample-primitives

**Umbrella**: Sample Primitives -> `Sample_Primitives`

**Internal targets**:
- Sample Primitives Core -> `Sample_Primitives_Core`

**Test Support**: Sample Primitives Test Support -> `Sample_Primitives_Test_Support`

---

### swift-set-primitives

**Umbrella**: Set Primitives -> `Set_Primitives`

**Internal targets**:
- Set Primitives Core -> `Set_Primitives_Core`
- Set Ordered Primitives -> `Set_Ordered_Primitives`

**Test Support**: Set Primitives Test Support -> `Set_Primitives_Test_Support`

---

### swift-rendering-primitives

**Umbrella**: Rendering Primitives -> `Rendering_Primitives`

**Internal targets**:
- Rendering Primitives Core -> `Rendering_Primitives_Core`
- Rendering Async Primitives -> `Rendering_Async_Primitives`

**Test Support**: Rendering Primitives Test Support -> `Rendering_Primitives_Test_Support`

---

### swift-algebra-affine-primitives

**Umbrella**: Algebra Affine Primitives -> `Algebra_Affine_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Algebra Affine Primitives Test Support -> `Algebra_Affine_Primitives_Test_Support`

---

### swift-algebra-cardinal-primitives

**Umbrella**: Algebra Cardinal Primitives -> `Algebra_Cardinal_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Algebra Cardinal Primitives Test Support -> `Algebra_Cardinal_Primitives_Test_Support`

---

### swift-algebra-modular-primitives

**Umbrella**: Algebra Modular Primitives -> `Algebra_Modular_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Algebra Modular Primitives Test Support -> `Algebra_Modular_Primitives_Test_Support`

---

### swift-bit-index-primitives

**Umbrella**: Bit Index Primitives -> `Bit_Index_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Bit Index Primitives Test Support -> `Bit_Index_Primitives_Test_Support`

---

### swift-bit-pack-primitives

**Umbrella**: Bit Pack Primitives -> `Bit_Pack_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Bit Pack Primitives Test Support -> `Bit_Pack_Primitives_Test_Support`

---

### swift-cyclic-index-primitives

**Umbrella**: Cyclic Index Primitives -> `Cyclic_Index_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Cyclic Index Primitives Test Support -> `Cyclic_Index_Primitives_Test_Support`

---

### swift-cyclic-primitives

**Umbrella**: Cyclic Primitives -> `Cyclic_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Cyclic Primitives Test Support -> `Cyclic_Primitives_Test_Support`

---

### swift-dimension-primitives

**Umbrella**: Dimension Primitives -> `Dimension_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Dimension Primitives Test Support -> `Dimension_Primitives_Test_Support`

---

### swift-geometry-primitives

**Umbrella**: Geometry Primitives -> `Geometry_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Geometry Primitives Test Support -> `Geometry_Primitives_Test_Support`

---

### swift-tagged-primitives

**Umbrella**: Identity Primitives -> `Tagged_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Tagged Primitives Test Support -> `Tagged_Primitives_Test_Support`

---

### swift-input-primitives

**Umbrella**: Input Primitives -> `Input_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Input Primitives Test Support -> `Input_Primitives_Test_Support`

---

### swift-lexer-primitives

**Umbrella**: Lexer Primitives -> `Lexer_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Lexer Primitives Test Support -> `Lexer_Primitives_Test_Support`

---

### swift-link-primitives

**Umbrella**: Link Primitives -> `Link_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Link Primitives Test Support -> `Link_Primitives_Test_Support`

---

### swift-source-primitives

**Umbrella**: Source Primitives -> `Source_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Source Primitives Test Support -> `Source_Primitives_Test_Support`

---

### swift-text-primitives

**Umbrella**: Text Primitives -> `Text_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Text Primitives Test Support -> `Text_Primitives_Test_Support`

---

### swift-token-primitives

**Umbrella**: Token Primitives -> `Token_Primitives`

**Internal targets**: (none -- single target)

**Test Support**: Token Primitives Test Support -> `Token_Primitives_Test_Support`

package e2e_test

import (
	"strings"
	"testing"
	"time"

	enums "e2e-test/skirout/enums"
	structs "e2e-test/skirout/structs"

	skir_client "github.com/gepheum/skir-go-client"
)

// =============================================================================
// Point: ordered builder, partial builder, getters, immutability, default
// =============================================================================

func TestPoint_orderedBuilder(t *testing.T) {
	p := structs.Point_builder().SetX(3).SetY(7).Build()
	if got := p.X(); got != 3 {
		t.Errorf("X() = %d, want 3", got)
	}
	if got := p.Y(); got != 7 {
		t.Errorf("Y() = %d, want 7", got)
	}
}

func TestPoint_partialBuilder(t *testing.T) {
	p := structs.Point_partialBuilder().SetY(5).Build()
	if got := p.X(); got != 0 {
		t.Errorf("X() = %d, want default 0", got)
	}
	if got := p.Y(); got != 5 {
		t.Errorf("Y() = %d, want 5", got)
	}
}

func TestPoint_default_returnsZeroValues(t *testing.T) {
	d := structs.Point_default()
	if d.X() != 0 || d.Y() != 0 {
		t.Errorf("default Point: X=%d Y=%d, want 0 0", d.X(), d.Y())
	}
}

func TestPoint_ToBuilder_copiesFields(t *testing.T) {
	p := structs.Point_builder().SetX(1).SetY(2).Build()
	p2 := p.ToBuilder().SetX(10).Build()
	if got := p2.X(); got != 10 {
		t.Errorf("X() = %d, want 10", got)
	}
	if got := p2.Y(); got != 2 {
		t.Errorf("Y() = %d, want 2 (unchanged)", got)
	}
	if got := p.X(); got != 1 {
		t.Errorf("original X() = %d, want 1 (immutable)", got)
	}
}

func TestPoint_String_containsFieldValues(t *testing.T) {
	p := structs.Point_builder().SetX(42).SetY(99).Build()
	s := p.String()
	if !strings.Contains(s, "42") || !strings.Contains(s, "99") {
		t.Errorf("String() = %q, want it to contain 42 and 99", s)
	}
}

// =============================================================================
// Color
// =============================================================================

func TestColor_orderedBuilder(t *testing.T) {
	c := structs.Color_builder().SetB(1).SetG(2).SetR(3).Build()
	if c.B() != 1 || c.G() != 2 || c.R() != 3 {
		t.Errorf("Color: B=%d G=%d R=%d, want 1 2 3", c.B(), c.G(), c.R())
	}
}

func TestColor_partialBuilder_setsIndividualFields(t *testing.T) {
	c := structs.Color_partialBuilder().SetR(255).Build()
	if c.R() != 255 || c.G() != 0 || c.B() != 0 {
		t.Errorf("Color: R=%d G=%d B=%d, want 255 0 0", c.R(), c.G(), c.B())
	}
}

// =============================================================================
// Triangle: struct-type field + array field
// =============================================================================

func TestTriangle_orderedBuilder(t *testing.T) {
	color := structs.Color_builder().SetB(0).SetG(0).SetR(255).Build()
	p1 := structs.Point_builder().SetX(0).SetY(0).Build()
	p2 := structs.Point_builder().SetX(1).SetY(0).Build()
	p3 := structs.Point_builder().SetX(0).SetY(1).Build()
	tri := structs.Triangle_builder().
		SetColor(color).
		SetPoints([]structs.Point{p1, p2, p3}).
		Build()
	if got := tri.Color().R(); got != 255 {
		t.Errorf("Color().R() = %d, want 255", got)
	}
	if got := tri.Points().Len(); got != 3 {
		t.Errorf("Points().Len() = %d, want 3", got)
	}
	if got := tri.Points().At(1).X(); got != 1 {
		t.Errorf("Points().At(1).X() = %d, want 1", got)
	}
}

func TestTriangle_default_colorIsDefault(t *testing.T) {
	d := structs.Triangle_default()
	if d.Color() != structs.Color_default() {
		t.Error("default Triangle's color should equal Color_default()")
	}
	if d.Points().Len() != 0 {
		t.Errorf("default Triangle points len = %d, want 0", d.Points().Len())
	}
}

func TestTriangle_SetColor_nilPanics(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Error("expected panic when setting nil Color")
		}
	}()
	structs.Triangle_builder().SetColor(nil)
}

func TestTriangle_ToBuilder_modifiesColor(t *testing.T) {
	color1 := structs.Color_builder().SetB(0).SetG(0).SetR(10).Build()
	color2 := structs.Color_builder().SetB(0).SetG(0).SetR(20).Build()
	tri := structs.Triangle_builder().SetColor(color1).SetPoints(nil).Build()
	tri2 := tri.ToBuilder().SetColor(color2).Build()
	if tri.Color().R() != 10 {
		t.Error("original color should be unchanged")
	}
	if tri2.Color().R() != 20 {
		t.Errorf("new color R() = %d, want 20", tri2.Color().R())
	}
}

// =============================================================================
// Item: all primitive field types
// =============================================================================

func TestItem_allPrimitiveFields(t *testing.T) {
	ts := time.UnixMilli(1000000).UTC()
	user := structs.Item_User_builder().SetId("u1").Build()
	item := structs.Item_builder().
		SetBool(true).
		SetBytes(skir_client.Bytes{}).
		SetInt32(42).
		SetInt64(1234567890123).
		SetOtherString("other").
		SetString("hello").
		SetTimestamp(ts).
		SetUser(user).
		SetWeekday(enums.Weekday_mondayConst()).
		Build()
	if !item.Bool() {
		t.Error("Bool() should be true")
	}
	if item.Int32() != 42 {
		t.Errorf("Int32() = %d, want 42", item.Int32())
	}
	if item.Int64() != 1234567890123 {
		t.Errorf("Int64() = %d, want 1234567890123", item.Int64())
	}
	if item.String_() != "hello" {
		t.Errorf("String_() = %q, want hello", item.String_())
	}
	if item.OtherString() != "other" {
		t.Errorf("OtherString() = %q, want other", item.OtherString())
	}
	if !item.Timestamp().Equal(ts) {
		t.Errorf("Timestamp() = %v, want %v", item.Timestamp(), ts)
	}
	if item.User().Id() != "u1" {
		t.Errorf("User().Id() = %q, want u1", item.User().Id())
	}
	if !item.Weekday().IsMondayConst() {
		t.Error("Weekday() should be monday")
	}
}

func TestItem_default_userIsDefault(t *testing.T) {
	d := structs.Item_default()
	if d.User() != structs.Item_User_default() {
		t.Error("default Item User should equal Item_User_default()")
	}
}

func TestItem_SetUser_nilPanics(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Error("expected panic when setting nil User")
		}
	}()
	structs.Item_partialBuilder().SetUser(nil)
}

// =============================================================================
// Items: keyed array Search methods
// =============================================================================

func TestItems_SearchByBool_found(t *testing.T) {
	item := structs.Item_partialBuilder().SetBool(true).Build()
	items := structs.Items_partialBuilder().SetArrayWithBoolKey([]structs.Item{item}).Build()
	if !items.ArrayWithBoolKey_SearchByBool(true).IsPresent() {
		t.Error("expected present Optional for bool key=true")
	}
}

func TestItems_SearchByBool_notFound(t *testing.T) {
	items := structs.Items_default()
	if items.ArrayWithBoolKey_SearchByBool(true).IsPresent() {
		t.Error("expected absent Optional for empty array")
	}
}

func TestItems_SearchByInt32(t *testing.T) {
	item := structs.Item_partialBuilder().SetInt32(99).Build()
	items := structs.Items_partialBuilder().SetArrayWithInt32Key([]structs.Item{item}).Build()
	got := items.ArrayWithInt32Key_SearchByInt32(99)
	if !got.IsPresent() {
		t.Fatal("expected present Optional for int32 key=99")
	}
	if got.Get().Int32() != 99 {
		t.Errorf("found item Int32() = %d, want 99", got.Get().Int32())
	}
}

func TestItems_SearchByInt64(t *testing.T) {
	item := structs.Item_partialBuilder().SetInt64(777).Build()
	items := structs.Items_partialBuilder().SetArrayWithInt64Key([]structs.Item{item}).Build()
	if !items.ArrayWithInt64Key_SearchByInt64(777).IsPresent() {
		t.Fatal("expected present Optional for int64 key=777")
	}
}

func TestItems_SearchByString(t *testing.T) {
	item := structs.Item_partialBuilder().SetString("needle").Build()
	items := structs.Items_partialBuilder().SetArrayWithStringKey([]structs.Item{item}).Build()
	if !items.ArrayWithStringKey_SearchByString("needle").IsPresent() {
		t.Error("expected to find item with string key=needle")
	}
	if items.ArrayWithStringKey_SearchByString("missing").IsPresent() {
		t.Error("expected absent for missing key")
	}
}

func TestItems_SearchByOtherString(t *testing.T) {
	item := structs.Item_partialBuilder().SetOtherString("other").Build()
	items := structs.Items_partialBuilder().SetArrayWithOtherStringKey([]structs.Item{item}).Build()
	if !items.ArrayWithOtherStringKey_SearchByOtherString("other").IsPresent() {
		t.Error("expected to find item with other_string key=other")
	}
}

func TestItems_SearchByTimestamp(t *testing.T) {
	ts := time.UnixMilli(42000).UTC()
	item := structs.Item_partialBuilder().SetTimestamp(ts).Build()
	items := structs.Items_partialBuilder().SetArrayWithTimestampKey([]structs.Item{item}).Build()
	if !items.ArrayWithTimestampKey_SearchByTimestamp(ts).IsPresent() {
		t.Error("expected to find item with timestamp key")
	}
}

func TestItems_SearchByEnumKind(t *testing.T) {
	item := structs.Item_partialBuilder().SetWeekday(enums.Weekday_mondayConst()).Build()
	items := structs.Items_partialBuilder().SetArrayWithEnumKey([]structs.Item{item}).Build()
	got := items.ArrayWithEnumKey_SearchByWeekdayKind(enums.Weekday_mondayConst().Kind())
	if !got.IsPresent() {
		t.Error("expected to find item with enum key=monday")
	}
}

func TestItems_SearchByUserId(t *testing.T) {
	item := structs.Item_partialBuilder().SetUser(structs.Item_User_builder().SetId("user-42").Build()).Build()
	items := structs.Items_partialBuilder().SetArrayWithWrapperKey([]structs.Item{item}).Build()
	if !items.ArrayWithWrapperKey_SearchByUserId("user-42").IsPresent() {
		t.Error("expected to find item by user.id")
	}
	if items.ArrayWithWrapperKey_SearchByUserId("nope").IsPresent() {
		t.Error("expected absent for wrong user.id")
	}
}

// The index is lazily built and cached; calling Search twice should give the same result.
func TestItems_SearchIsCached(t *testing.T) {
	item := structs.Item_partialBuilder().SetInt32(7).Build()
	items := structs.Items_partialBuilder().SetArrayWithInt32Key([]structs.Item{item}).Build()
	r1 := items.ArrayWithInt32Key_SearchByInt32(7)
	r2 := items.ArrayWithInt32Key_SearchByInt32(7)
	if r1.Get().Int32() != r2.Get().Int32() {
		t.Error("second Search call should return same result (cached index)")
	}
}

// Rebuilding via ToBuilder with a new array resets the index.
func TestItems_ToBuilder_setsNewArrayResetsIndex(t *testing.T) {
	item1 := structs.Item_partialBuilder().SetInt32(1).Build()
	item2 := structs.Item_partialBuilder().SetInt32(2).Build()
	items := structs.Items_partialBuilder().SetArrayWithInt32Key([]structs.Item{item1}).Build()
	items.ArrayWithInt32Key_SearchByInt32(1) // warm the cache
	items2 := items.ToBuilder().SetArrayWithInt32Key([]structs.Item{item2}).Build()
	if items2.ArrayWithInt32Key_SearchByInt32(1).IsPresent() {
		t.Error("old item should not be found after replacing the array")
	}
	if !items2.ArrayWithInt32Key_SearchByInt32(2).IsPresent() {
		t.Error("new item should be found after replacing the array")
	}
}

// =============================================================================
// Optional fields: SetFoo_Absent / SetFoo_Present helpers
// =============================================================================

func TestFoo_Bar_SetBar_Present(t *testing.T) {
	bar := structs.Foo_Bar_builder().SetBar_Present("hello").SetFoos_Absent().Build()
	if !bar.Bar().IsPresent() {
		t.Fatal("Bar() should be present")
	}
	if got := bar.Bar().Get(); got != "hello" {
		t.Errorf("Bar().Get() = %q, want hello", got)
	}
}

func TestFoo_Bar_SetBar_Absent(t *testing.T) {
	bar := structs.Foo_Bar_builder().SetBar_Absent().SetFoos_Absent().Build()
	if bar.Bar().IsPresent() {
		t.Error("Bar() should be absent")
	}
}

func TestFoo_Bar_SetFoos_Present(t *testing.T) {
	bar := structs.Foo_Bar_builder().
		SetBar_Absent().
		SetFoos_Present(skir_client.Array[skir_client.Optional[structs.Foo]]{}).
		Build()
	if !bar.Foos().IsPresent() {
		t.Error("Foos() should be present")
	}
}

func TestFoo_Bar_SetFoos_viaSetFoos(t *testing.T) {
	opt := skir_client.OptionalOf(skir_client.Array[skir_client.Optional[structs.Foo]]{})
	bar := structs.Foo_Bar_builder().SetBar_Absent().SetFoos(opt).Build()
	if !bar.Foos().IsPresent() {
		t.Error("Foos() should be present when set via SetFoos")
	}
}

func TestFoo_SetBars_Absent(t *testing.T) {
	foo := structs.Foo_builder().SetBars_Absent().SetZoos_Absent().Build()
	if foo.Bars().IsPresent() {
		t.Error("Bars() should be absent")
	}
}

func TestFoo_SetBars_Present(t *testing.T) {
	foo := structs.Foo_builder().
		SetBars_Present(skir_client.Array[structs.Foo_Bar]{}).
		SetZoos_Absent().
		Build()
	if !foo.Bars().IsPresent() {
		t.Error("Bars() should be present")
	}
}

func TestTrue_SetToFrozen_Present(t *testing.T) {
	tr := structs.True_builder().
		SetAnd_Absent().
		SetBy(false).
		SetField(false).
		SetGet(false).
		SetIt(nil).
		SetSelf(nil).
		SetToFrozen_Present(true).
		SetToMutable_Absent().
		Build()
	if !tr.ToFrozen().IsPresent() {
		t.Fatal("ToFrozen() should be present")
	}
	if !tr.ToFrozen().Get() {
		t.Error("ToFrozen().Get() should be true")
	}
}

func TestTrue_SetToFrozen_Absent(t *testing.T) {
	tr := structs.True_builder().
		SetAnd_Absent().
		SetBy(false).
		SetField(false).
		SetGet(false).
		SetIt(nil).
		SetSelf(nil).
		SetToFrozen_Absent().
		SetToMutable_Absent().
		Build()
	if tr.ToFrozen().IsPresent() {
		t.Error("ToFrozen() should be absent")
	}
}

// =============================================================================
// True: keyed array with float32 key
// =============================================================================

func TestTrue_It_SearchByX(t *testing.T) {
	f1 := structs.Floats_builder().SetX(1.5).SetY(0).Build()
	f2 := structs.Floats_builder().SetX(2.5).SetY(0).Build()
	tr := structs.True_partialBuilder().SetIt([]structs.Floats{f1, f2}).Build()
	got := tr.It_SearchByX(1.5)
	if !got.IsPresent() {
		t.Fatal("expected to find Floats with X=1.5")
	}
	if got.Get().X() != 1.5 {
		t.Errorf("X() = %v, want 1.5", got.Get().X())
	}
	if tr.It_SearchByX(9.9).IsPresent() {
		t.Error("expected absent for X=9.9")
	}
}

// =============================================================================
// FullName: partial builder, String()
// =============================================================================

func TestFullName_partialBuilder(t *testing.T) {
	fn := structs.FullName_partialBuilder().
		SetFirstName("John").
		SetLastName("Doe").
		Build()
	if fn.FirstName() != "John" {
		t.Errorf("FirstName() = %q, want John", fn.FirstName())
	}
	if fn.LastName() != "Doe" {
		t.Errorf("LastName() = %q, want Doe", fn.LastName())
	}
	if fn.Suffix() != "" {
		t.Errorf("Suffix() = %q, want empty", fn.Suffix())
	}
}

func TestFullName_String_containsNames(t *testing.T) {
	fn := structs.FullName_builder().
		SetFirstName("Alice").
		SetLastName("Smith").
		SetSuffix("Jr").
		Build()
	s := fn.String()
	if !strings.Contains(s, "Alice") || !strings.Contains(s, "Smith") {
		t.Errorf("String() = %q, expected Alice and Smith", s)
	}
}

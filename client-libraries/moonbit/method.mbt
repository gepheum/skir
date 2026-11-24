///|
pub(all) struct Method[T, U] {
  name : String
  number : Int
  request_serializer : Serializer[T]
  response_serializer : Serializer[U]
  doc : String
}

/// Un valor está dentro de la meta si se consumió algo y queda entre el 90 % y el
/// 110 % de ella (límites incluidos). Es la regla de `goal_met` del backend para
/// las calorías (HU-11); HU-22 y HU-23 la aplican también a proteína y grasa.
bool withinGoal(double consumed, double? goal) =>
    goal != null &&
    goal > 0 &&
    consumed > 0 &&
    consumed * 10 >= goal * 9 &&
    consumed * 10 <= goal * 11;

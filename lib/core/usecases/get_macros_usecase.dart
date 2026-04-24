import '../repositories/macro_repository.dart';
import '../entities/macro.dart';

class GetMacrosUseCase {
  final MacroRepository _macroRepository;

  GetMacrosUseCase(this._macroRepository);

  Future<List<Macro>> execute() async {
    return await _macroRepository.getAll();
  }

  Future<List<Macro>> getByCategory(String category) async {
    return await _macroRepository.getByCategory(category);
  }

  Future<List<Macro>> getFavorites() async {
    return await _macroRepository.getFavorites();
  }

  Future<List<Macro>> searchByTrigger(String trigger) async {
    return await _macroRepository.searchByTrigger(trigger);
  }
}
